#define _GNU_SOURCE
#include <sys/types.h>
#include <sys/wait.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sched.h>
#include <string.h>

char * const child_args[] = {
	"/usr/bin/zsh",
	NULL
};

int pipefd[2];

int child_fn (void *arg) {
	int rc;
	char c;

	printf("-- [%5d] World!\n", getpid());

	close(pipefd[1]);

	if(read(pipefd[0], &c, 1) == -1) {
		perror("read");
		exit(EXIT_FAILURE);
	}

	rc = sethostname(arg, strlen(arg));
	if(rc < 0) {
		perror("sethostname");
		exit(EXIT_FAILURE);
	}

	rc = execv(child_args[0], child_args);
	if(rc < 0) {
		perror("execv");
		exit(EXIT_FAILURE);
	}

	/* Never reach here */
	printf("Ooops!\n");
	return 1;
}

#define STACK_SIZE 4*1024
static char child_stack[STACK_SIZE];
char *top_stack = child_stack + STACK_SIZE;

int main(void)
{
	pid_t child_tid;
	int status;

	printf("-- [%5d] Hello?\n", getpid());

	if(pipe(pipefd) == -1) {
		perror("pipe");
		return EXIT_FAILURE;
	}

	child_tid = clone(child_fn, top_stack,
			  CLONE_NEWUTS | CLONE_NEWIPC | CLONE_NEWPID | SIGCHLD,
			  "In namespace");
	if (child_tid < 0) {
		perror("clone");
		return EXIT_FAILURE;
	}

	sleep(2);
	/* close the write side */
	close(pipefd[1]);

	child_tid = waitpid(child_tid, &status, 0);
	if (child_tid < 0) {
		perror("waitpid");
		return EXIT_FAILURE;
	}

	printf("-- Child exit code: %d\n", status);

	return EXIT_SUCCESS;
}
