#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sched.h>
#include <sys/wait.h>

int child_fn (void *arg) {
	printf("-- World!\n");

	return 0;
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

	printf("Child exit code: %d\n", status);

	return EXIT_SUCCESS;
}
