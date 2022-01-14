// addons.c 
// C functions used by FORTH

#include <sys/select.h>
#include <string.h> 
#include <stdlib.h>
#include <stdio.h>

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

// sorted string pool  
// I got fed up with the string literal pool, and added this for the time being.

const int pool_size = 4096;
int next_string=0;
 
char* pool[pool_size];

int stringcompare(const void *a, const void *b) {
     // look at string pointers
     if( a == NULL && b == NULL) return 0;
     if( a == NULL && b != NULL) return 1;
     if( a != NULL && b == NULL) return -1; 
     // other wise look at string contents
     char* as = *(char **)a;
     char* bs = *(char **)b;
     //printf("\ncompare %s with %s", as, bs);
     int r = strncmp(   as, bs, 256 );  
     return r;
}

extern void init_string_pool() {
      for( int i=0; i<pool_size; i++)  { 
             pool[i]=NULL;
      }
}

int free_index() {
        for( int i=0; i < pool_size; i++) {
                if (pool[i]==NULL ) return i;
        }
        return -1;
}

void sort_strings() {
      qsort( pool, next_string, sizeof(char *), stringcompare);       
}

char** find_string( const char *s) {
        const char* key = s; 
        return  (char**)bsearch( (const void *)&key, pool, next_string, sizeof(char*), stringcompare);                
}

extern void list_strings() {
        puts("\nList literal strings");
        printf("\nCapacity %d used %d", pool_size, next_string-1);
        for(int i=0; i<pool_size; i++) {
               if( pool[i] != NULL) {
                     printf("\n%3d - %s", i, pool[i]);
                }
        }
}

void del_string( const char* s) {
        char** l =find_string(s);
        int n=((long)l-(long)&pool)/sizeof(char*); 
        // printf("\ndel: %s", pool[n]);
        if( pool[n] !=NULL) {
                free(pool[n]);
        }
        for( int i=n; i<pool_size-1; i++) {
                pool[i]=pool[i+1];
        }
        next_string--;
}

extern long locate_string( const char* s) {
        char** l= find_string(s);
        if( l==NULL) {
                return 0;
        }
        // int n=((long)l-(long)&pool)/sizeof(char*); 
        return (long)*l;
}

// add string literal. if we dont have it already
extern long add_string( const char* s) {
        long l=locate_string(s);
        if( l==0) {
                pool[next_string] = strdup(s);
                l=(long)pool[next_string];
                next_string++;
                sort_strings();
        }
        return l;
}

 