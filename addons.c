// addons.c 
// C functions used by FORTH

#include <sys/select.h>

// used by KEY? to tell if there is any pending key press.
extern int kb_hit(void)
{

        fd_set read_fd; 
        struct timeval tv ;
        tv.tv_sec=0;
        tv.tv_usec=0;

        FD_ZERO(&read_fd);
        FD_SET(0, &read_fd);
        return select( 1, &read_fd, 0, 0, &tv);

}

 