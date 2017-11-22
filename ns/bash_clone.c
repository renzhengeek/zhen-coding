#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sched.h>
#include <sys/wait.h>

char * const child_args[] = {
	"/usr/bin/zsh",
	NULL
};

int child_fn (void *arg) {
	int rc;

	printf("-- World!\n");
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

	printf("-- Hello?\n");

	child_tid = clone(child_fn, top_stack, SIGCHLD, NULL);
	if (child_tid < 0) {
		perror("clone");
		return EXIT_FAILURE;
	}

	child_tid = waitpid(child_tid, &status, 0);
	if (child_tid < 0) {
		perror("waitpid");
		return EXIT_FAILURE;
	}

	printf("-- Child exit code: %d\n", status);

	return EXIT_SUCCESS;
}
