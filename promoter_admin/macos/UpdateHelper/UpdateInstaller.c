#include <unistd.h>

/* Launch Services starts this app outside the sandbox. It only execs the
   install script it was given. */
int main(int argc, char **argv) {
  const char *script = NULL;
  for (int i = 1; i < argc; i++) {
    script = argv[i];
  }
  if (script == NULL) {
    return 2;
  }
  execl("/bin/bash", "bash", script, (char *)0);
  return 127;
}
