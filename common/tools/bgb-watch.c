/*
launcher for wine bgb.exe
by ax6, 2020-06-27
license: Creative Commons Zero (CC0)

This program is untested, but it will eventually become a wrapper
allowing `make bgb-watch` to start BGB if and only if it is not
already running.
*/

#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>

int main (int argc, char ** argv) {
  if (argc != 2) return 1;
  int fd = open("bgb.lock", O_CREAT | O_EXCL | O_CLOEXEC, 0755);
  if (fd < 0) return 0; // file exists
  if (fork()) return 0; // exit the parent, keep the child
  int child = fork();
  if (!child) {
    execlp("bgb.exe", "bgb.exe", "-watch", argv[1], NULL);
    abort();
  }
  waitpid(child, NULL, 0);
  close(fd);
  unlink("bgb.lock");
  return 0;
}
