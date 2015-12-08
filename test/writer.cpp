#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/time.h>
#include <unistd.h>
#include <memory.h>
#include <ios>
#include <iostream>
#include <iomanip>
#include <errno.h>
#include <malloc.h>
#include <cstdlib>

using namespace std;
//
//  forward declarations (prototypes)
//
long delta_t (struct timeval & t2, struct timeval & t1);
void dowrite( int * buffer, const char * file, int nCount);
void doread ( int * buffer, const char * file, int nCount);
void Help();
//
//  global variables
//
bool bVerbose = false;
bool bDirect  = false;
bool bLoop    = false;
const char SUBNAM[]="writer";
      size_t RECLEN=4096;       // record buffer length
const size_t BLKALIGN=4096;     // for memalign
//-----------------------------------------
// Funktion      : writer
// Erstellt      : 04.10.15
// Zweck         : testet low level read und write unter Linux
//
//              =========================
//              direct i/o c++ example (here a 1 MB file, virtual machine)
//              =========================
//              normal I/O: 25 msecs (create+write)
//              normal I/O: 6  msecs (write)
//              direct I/O: 4000 msecs (create+write)
//              normal I/O: 130  msecs (write)
//
//	generate executable:
//	g++ writer.cpp -o writer.x
//
//
// Rückgabewert  : int  immer 0
// Argument(e)   : siehe Helpfunktion
//
// Calls         :
// Called by     :
//-----------------------------------------
int main(int iargc, char** argv)
{   char szFile[128] = "test.bin";
    int nCount;
    int nFillen=1000;
    char * szError;
    bool bWrite = false;
    int i,ib;

    int *buffer;
	if(iargc == 1)
	{	Help();
		return 0;
	}
    ib = 0;
//
//  command line processing, first options
//
    for (i=1;i<iargc;i++)
    {   if(*argv[i] == '-' )
        {   switch (*(argv[i]+1))
            {   case 'v': bVerbose = true;  break;
                case 'd': bDirect  = true;  break;
                case 'w': bWrite   = true;  break;
                case 'l': bLoop    = true;  break;
                case 'h': Help();           return 0;
                default:  { ib=atoi(argv[i]+1);
                            if(ib == 0)
                            {   cerr<<"wrong buffer length or unrecognized switch"<<endl;
                                return -1;
                            }
                            else
                            {   RECLEN=1024*ib;
                                break;
                            }
                          }
            }
        }
    }
    if(bDirect && ib!=0)
    {   cerr<<"for direct write no block length change possible"<<endl;
        return -1;
    }

//
//  command line processing, now parameters
//
    int n=0;
    for (i=1;i<iargc;i++)
    {   if(*argv[i] == '-' ) continue;
        n++;
        if(n==1)  strcpy (szFile,argv[i]);  // 1st Parameter file name
        if(n==2)                            // 2nd Parameter length in kB
        {   nFillen=atoi(argv[i]);
            if(nFillen <= 0)  {cout<<"unrecognized file length"<<endl;  return 0;}
        }
    }
    nCount = (nFillen*1024)/RECLEN;
    cout<<"buffer length/nCount = "<<RECLEN<<' '<<nCount<<endl;
    buffer=(int*)memalign(BLKALIGN,RECLEN);    // necessary for direct read/write
    memset(buffer,0,RECLEN/sizeof(int));
    if(bWrite)  dowrite(buffer,szFile,nCount);
    else        doread (buffer,szFile,nCount);
    return 0;
}
void dowrite( int * buffer, const char * file, int nCount)
{
    struct timeval start, end;
    int ierr;
    int flag;
    long dt;
    int nc=0;

    if(bDirect) flag=O_RDWR|O_CREAT|O_DIRECT|O_SYNC;
    else        flag=O_RDWR|O_CREAT;
    int mode=S_IREAD | S_IWRITE;
    int fh = open(file,flag,mode);
    if(fh < 0) { cout<<"open error"<<endl; return;}
    while(true)
    {   gettimeofday(&start, NULL);
        lseek(fh,SEEK_SET,0);
		cout<<setw(4)<<++nc<<"| ";
        for (int i=0;i<nCount;i++)
        {   *buffer = i+1;
           ierr = write(fh,buffer,RECLEN);
           if(bVerbose && i<10) cout<<*buffer<<' ';
           if(bVerbose && i==nCount-1) cout<<"..."<<*buffer;
           if(ierr < 0)
           {    cout<<"buffer length "<<sizeof(*buffer)<<endl;
                cout<<"write error, record "<<i+1<<" errno= "<<errno<<" ("<<strerror(errno)<<')'<<endl;
                break;
           }
        }
        gettimeofday(&end, NULL);
        dt=delta_t(end,start);
        if(bVerbose)  cout<<" write time:"<<dt<<" msecs"<<endl;
        if( !bLoop)  break;
        sleep(1);
    }
    return;
}
void doread( int * buffer, const char * file, int nCount)
{   struct timeval start, end;
    int ierr;
    int flag;
    long dt;
    int nc=0;

    if(access(file,F_OK))
    {   cout<<file<<" does not exist, create it first"<<endl;
        return;
    }
    if(bDirect) flag=O_RDWR|O_DIRECT|O_SYNC;
    else        flag=O_RDWR;
    int fh = open(file,flag);
    if(fh < 0) { cout<<"open error"<<endl; return;}
    while(true)
    {   gettimeofday(&start, NULL);
        lseek(fh,SEEK_SET,0);
		cout<<setw(4)<<++nc<<"| ";
        for (int i=0;i<nCount;i++)
        {  *buffer = i+1;
           ierr = read(fh,buffer,RECLEN);
           if(bVerbose && i<10) cout<<*buffer<<' ';
           if(bVerbose && i==nCount-1) cout<<"..."<<*buffer;
           if(ierr < 0)
           {    cout<<"buffer length "<<sizeof(*buffer)<<endl;
                cout<<"read error, record "<<i+1<<" errno= "<<errno<<" ("<<strerror(errno)<<')'<<endl;
                break;
           }
        }
        gettimeofday(&end, NULL);
//        cout<<':'<<start.tv_sec<<' '<<start.tv_usec<<' '<<end.tv_sec<<' '<<end.tv_usec<<"  :  ";
        dt=delta_t(end,start);
        if(bVerbose)  cout<<" read time:"<<dt<<" msec"<<endl;
        if( !bLoop)  break;
        sleep(1);
    }
    return;
}
long delta_t (struct timeval & t2, struct timeval & t1)
{   long mtime, seconds, useconds;
    seconds  = t2.tv_sec  - t1.tv_sec;
    useconds = t2.tv_usec - t1.tv_usec;
    mtime = (long) (((seconds) * 1000.0 + useconds/1000.0) + 0.5);
    return mtime;
}
void Help()
{   cout<<SUBNAM<<" tests read and write of files"<<endl;
    cout<<"usage: "<<SUBNAM<<" [options]  [ file length ]"<<endl;
    cout<<"Options:"<<endl;
    cout<<"\t-v\tVerbose"<<endl;
    cout<<"\t-d\tsynchronized (def=buffered)"<<endl;
    cout<<"\t-w\twrite        (def=read)"    <<endl;
    cout<<"\t-n\tn=buffer length in kB (def=4)"<<endl;
    cout<<"\t-l\tinfinite loop"              <<endl;
    cout<<"\tfile\tfile to be accessed (def=test.bin)"<<endl;
    cout<<"\tlength\tlength of file in kB (def=1000)"<<endl;
}
