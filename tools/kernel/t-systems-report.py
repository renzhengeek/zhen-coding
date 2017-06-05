# vim:set shiftwidth=4 softtabstop=4 expandtab textwidth=79:
from __future__ import absolute_import
from __future__ import print_function
import gdb
import argparse

from crash.commands import CrashCommand, CommandRuntimeError
from crash.types.blockdev import for_each_block_device, block_device_name, gendisk_name
from crash.types.list import list_for_each_entry
from crash.types.util import container_of


jiffies = gdb.lookup_global_symbol("jiffies").value()

def jiffies_to_msec(j):
    hz = 250
    return 1000 / hz * j

def page_private(page):
    private = long(gdb.lookup_symbol("PG_private", None)[0].value())
    return page['flags'] & (1 << private) != 0

def page_to_inode(page):
    return page['mapping']['host']
    return None

def print_bio_bvec(bio):
    for i in range(0, bio['bi_vcnt']):
        page = bio['bi_io_vec'][i]['bv_page']
        if not page_private(page) and long(page['mapping']) != 0:
            print(page['mapping']['host']['i_sb']['s_type'])

clone_rel = {}

def get_sym_helper(name, block=None):
    return gdb.lookup_symbol(name, block)[0].value().address

def print_buffer_head(bh):
    x = gdb.lookup_symbol("journal_commit_transaction", None)[0] # ext3
    b = gdb.block_for_pc(long(x.value().address))
    journal_end_buffer_io_sync = get_sym_helper('journal_end_buffer_io_sync', b)
    journal_head = gdb.lookup_type('struct journal_head', b)

    page = bh['b_page']
    inode = page['mapping']['host']
    sb = inode['i_sb']

    # ext3 journal buffer
    if bh['b_end_io'] == journal_end_buffer_io_sync:
        fstype = "journal on ext3"
        return "bh {:#x} for {} fs on dev {}".format(long(bh), fstype, block_device_name(bh['b_bdev']))
    else:
        fstype = sb['s_type']['name'].string()
        return "bh {:#x} for {} fs, inode {} on dev {}".format(long(bh), fstype, inode['i_ino'], block_device_name(bh['b_bdev']))


bio_map = {}
bio_duration = {}

def print_bio_chain(bio, duration):
    end_clone_bio = get_sym_helper("end_clone_bio")
    clone_endio = get_sym_helper("clone_endio")
    multipath_end_io = get_sym_helper("multipath_end_io")
    end_bio_bh = get_sym_helper("end_bio_bh_io_sync")
    xfs_bio_end = get_sym_helper("xfs_buf_bio_end_io")
    xlog_iodone = get_sym_helper("xlog_iodone")
    dio_bio_end = get_sym_helper("dio_bio_end_io")
    dio_bio_end_aio = get_sym_helper("dio_bio_end_aio")
    xfs_buf_iodone_callbacks = get_sym_helper("xfs_buf_iodone_callbacks")
    mpage_end_io = get_sym_helper("mpage_end_io")

    dm_target_io = gdb.lookup_type("struct dm_target_io")
    rq_info = gdb.lookup_type("struct dm_rq_clone_bio_info")
    buffer_head = gdb.lookup_type("struct buffer_head")
    xfs_buf = gdb.lookup_type("xfs_buf_t")
    dio = gdb.lookup_type("struct dio")
    xfs_log_item = gdb.lookup_type("struct xfs_log_item")
    xfs_inode_log_item = gdb.lookup_type("struct xfs_inode_log_item")

    global clone_rel
    if long(bio) in clone_rel:
        related = long(clone_rel[long(bio)])
        return "related to already-seen bio {:#x}".format(related)

    bio_duration[long(bio)] = duration

    for i in range(0, bio['bi_vcnt']):
        page = bio['bi_io_vec'][i]['bv_page']
        bio_map[long(page)] = bio

    if bio['bi_end_io'] == end_clone_bio:
        info = bio['bi_private'].cast(rq_info.pointer())
        count = bio['bi_cnt']['counter']
#        print("   cloned request-based dm bio, count = {}".format(count))
#        if count > 1:
#            print("  will assume completion and skip related bios later")
#        clone_rel[long(bio)] = info['orig']
        b = bio['bi_next']
        while long(b) != 0:
            clone_rel[long(b)] = bio
            b = b['bi_next']
        bio = info['orig']
#        print("     mapping to bio {:#x}: {}".format(long(bio), bio['bi_end_io']))
        return print_bio_chain(info['orig'], duration)
    elif bio['bi_end_io'] == clone_endio:
        tio = bio['bi_private'].cast(dm_target_io.pointer())
        io = tio['io']
#        print("     io has count {}".format(io['io_count']['counter']))
        return print_bio_chain(io['bio'], duration)
    elif bio['bi_end_io'] == end_bio_bh:
        bh = bio['bi_private'].cast(buffer_head.pointer())
        return print_buffer_head(bh)
    elif bio['bi_end_io'] == xfs_bio_end:
        buf = bio['bi_private'].cast(xfs_buf.pointer())
        if long(buf['b_iodone']) != 0:
            if buf['b_iodone'] == xlog_iodone:
                return "XFS log buffer at {} on {}".format(bio['bi_sector'] * 512,
                        block_device_name(bio['bi_bdev']))
            elif buf['b_iodone'] == xfs_buf_iodone_callbacks:
                lip = buf['b_fspriv'].cast(xfs_log_item.pointer())
                while long(lip) != 0:
                    inode = container_of(lip, 'struct xfs_inode_log_item', 'ili_item')['ili_inode']

                    print("buffer callback for inode {} (iocount {})".format(inode['i_vnode']['i_ino'], inode['i_iocount']['counter']))
                    lip = lip['li_bio_list']

                return "buffer callback"
            return str(buf['b_iodone'])
        else:
            return "async xfs buf"
        print(buf.dereference())

    elif bio['bi_end_io'] == dio_bio_end or bio['bi_end_io'] == dio_bio_end_aio:
        dio = bio['bi_private'].cast(dio.pointer())
        fstype = dio['inode']['i_sb']['s_type']['name'].string()
        dev = block_device_name(dio['inode']['i_sb']['s_bdev'])
        offset = dio['block_in_file'] << dio['blkbits']
        return "direct I/O for inode {:#x}/{} [{}/{}] on {} fs on dev {}".format(long(dio['inode']), dio['inode']['i_ino'], offset, dio['size'], fstype, dev)
        print(dio.dereference())

    elif bio['bi_end_io'] == mpage_end_io:
        global bio_map
        inode = bio['bi_io_vec'][0]['bv_page']['mapping']['host']
        fstype = inode['i_sb']['s_type']['name'].string()
        dev = block_device_name(inode['i_sb']['s_bdev'])
#        for i in range(0, bio['bi_vcnt']):
#            page = bio['bi_io_vec'][i]['bv_page']
#            bio_map[long(page)] = bio
        return "multipage I/O for inode {:#x}/{} on fs {} on dev {}".format(long(inode), inode['i_ino'], fstype, dev)

    else:
        return "unhandled: {}".format(bio['bi_end_io'].dereference())

for dev in for_each_block_device():
    q = dev['queue']
    header = False
    total = 0
    for req in list_for_each_entry(q['queue_head'], 'struct request',
        'queuelist'):
        duration_ms = jiffies_to_msec(jiffies - req['start_time'])
        if not header:
            header = True
            print("Requests for {}".format(gendisk_name(dev)))
        print(" req stuck for {}.{}s".format(duration_ms / 1000, duration_ms %
        1000))
        bio = req['bio']
        count = 0
        while long(bio) != 0:
            print("  bio {}: {:#x}".format(count, long(bio)))
            print("    {}".format(print_bio_chain(bio, duration_ms)))
            bio = bio['bi_next']
            count += 1
        total += 1
    if total:
        print(" {} total requests in queue_head".format(total))

    if q['timeout_list'].address != q['timeout_list']['next']:
        print(" timeout list: {}".format(q['timeout_list']))

def dump_waiter(pid, inode):
    bdev = block_device_name(inode['i_sb']['s_bdev'])
    print("PID {} waiting on {}, fs {}, inode {:#x}/{}".format(pid, bdev,
          inode['i_sb']['s_type']['name'].string(),
                                    long(inode.address), inode['i_ino']))

def dump_page_waiter(pid, page, why):
    print("PID {} waiting on page {} {:#x}".format(pid, why, long(page)))
    global bio_map
    if long(page) in bio_map:
        bio = bio_map[long(page)]
        duration = bio_duration[long(bio)]
        print("-> Attached to queued bio {:#x} (queued {}.{}s ago)".format(long(bio), duration / 1000, duration % 1000))
    inode = page_to_inode(page)
    if inode:
        print("-> ", end='')
        dump_waiter(pid, inode)

def dump_page_wq_waiter(pid, wq, why):
    page = container_of(wq['key']['flags'], 'struct page', 'flags')
    dump_page_waiter(pid, page.address, why)

page_type = gdb.lookup_type('struct page')
print("Inspecting stack traces")
for thread in gdb.selected_inferior().threads():
    thread.switch()
    pid = thread.ptid[1]
    try:
        f = gdb.newest_frame()
        get_inode = False
        while f.type() != gdb.SIGTRAMP_FRAME:
            try:
                f = f.older()
            except Exception as e:
                break
            fn = f.name()
            if not fn:
                break
            pc = f.pc()
            try:
                if fn == 'xfs_ioend_wait':
                    get_inode = True
                    continue
                if get_inode:
                    get_inode = False
                    inode = f.read_var('ip')
                    dump_waiter(pid, inode['i_vnode'])
                    break
                if fn == '__wait_on_bit':
                    wq = f.read_var('q').dereference()
                    continue

                if fn == '__lock_page' or fn == '__lock_page_killable':
                    page = f.read_var('page')
                    dump_page_waiter(pid, page, 'lock')

                if fn == 'wait_on_page_writeback':
                    dump_page_wq_waiter(pid, wq, 'writeback')
                    break
            except Exception as e:
                print("{} in {}/{}".format(e, thread.ptid, fn))
                break

    except gdb.error as e:
        pass
