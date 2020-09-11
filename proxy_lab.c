/*
 * Author: Fan Bu
 * A concurrent proxy that can process HTTP requests and cache recent requested web objects.
 * Written for the course "15-213 Introduction to Computer Systems" at Carnegie Mellon University.
 */

#include "csapp.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <ctype.h>
#include <stdbool.h>
#include <inttypes.h>
#include <unistd.h>
#include <assert.h>

#include <pthread.h>
#include <signal.h>
#include <errno.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

/*
 * Debug macros, which can be enabled by adding -DDEBUG in the Makefile
 */
#ifdef DEBUG
#define dbg_assert(...) assert(__VA_ARGS__)
#define dbg_printf(...) fprintf(stderr, __VA_ARGS__)
#else
#define dbg_assert(...)
#define dbg_printf(...)
#endif

#define MAX_NUM_HEADERS (100)

/*
 * Max cache and object sizes
 */
#define MAX_CACHE_SIZE (1024*1024)
#define MAX_OBJECT_SIZE (100*1024)

typedef struct sockaddr SA;

/*
 * Struct for HTTP requests
 */
typedef struct {
    char hostname[MAXLINE];
    char port[MAXLINE];
    char path[MAXLINE];
} HTTPRequest;

/*
 * Struct for HTTP request headers
 */
typedef struct{
    char name[MAXLINE];
    char value[MAXLINE];
} RequestHeader;

/*
 * Struct for a block in the cache, where
 * each block contains a web object and
 * its associated URI.
 */
typedef struct cache_b{
    size_t size;
    char uri[MAXLINE];
    char *content;
    struct cache_b *prev;
    struct cache_b *next;
} cache_b;

cache_b *cache = NULL;
size_t cache_size = 0;
pthread_mutex_t cache_mutex;


/*
 * insert_cache: Function that inserts a web oject into the cache,
 * it takes the URI as the key to acess the web oject later,
 * a pointer to the already allocated web oject, and the size
 * in bytes of the allocated web object. If the cache does not
 * have enough space left, it will evict the least recently used
 * web object.
 */
void insert_cache(char* uri, char* content, size_t size){
    pthread_mutex_lock(&cache_mutex);

    //Least Recently Used eviction
    while (cache_size + size > MAX_CACHE_SIZE){
        cache_b* last = cache->prev;
        cache_size -= last->size;
        last->prev->next = last->next;
        last->next->prev = last->prev;
        free(last->content);
        free(last);
    }

    cache_b *new_cache = malloc(sizeof(cache_b));
    new_cache->size = size;
    strcpy(new_cache->uri,uri);
    new_cache->content = content;

    if (cache == NULL){
        new_cache->prev = new_cache;
        new_cache->next = new_cache;
    }else{
        new_cache->prev = cache->prev;
        new_cache->next = cache;
        cache->prev->next = new_cache;
        cache->prev = new_cache;
    }
    cache = new_cache;
    cache_size += size;

    pthread_mutex_unlock(&cache_mutex);
}

/*
 * lookup_cache: Function that looks up a web oject from the cache.
 * It takes the URI as the key to find the associated web object.
 * If alloc is set to true, the function will allocate a space in memory,
 * copy the content of the web oject to that memory, and return the pointer
 * that points to that meory. If alloc is set to false, then the function will
 * directly return the pointer that points to the content in the cache. This
 * function also takes in a size argument, which is used to return the size of
 * the web object if found if size is not NULL.
 */
char* lookup_cache(char* uri, size_t* size, bool alloc){
    pthread_mutex_lock(&cache_mutex);

    if (cache == NULL){
        pthread_mutex_unlock(&cache_mutex);
        return NULL;
    }

    cache_b* matched_cache = NULL;

    if (strcmp(cache->uri, uri)){
        cache_b *tmp = cache;
        while (tmp->next != cache){
            tmp = tmp->next;
            if (strcmp(tmp->uri, uri) == 0){
                tmp->prev->next = tmp->next;
                tmp->next->prev = tmp->prev;
                tmp->prev = cache->prev;
                tmp->next = cache;
                cache->prev->next = tmp;
                cache->prev = tmp;
                cache = tmp;
                matched_cache = cache;
                break;
            }else{
            }
        }
    }else{
        matched_cache = cache;
    }

    if (matched_cache == NULL){
        pthread_mutex_unlock(&cache_mutex);
        return NULL;
    }

    char* content;

    if (alloc){
        content = malloc(matched_cache->size);
        memcpy(content, matched_cache->content, matched_cache->size);
    }else{
        content = matched_cache->content;
    }

    if (size != NULL) *size = matched_cache->size;

    pthread_mutex_unlock(&cache_mutex);
    return content;
}

/*
 * String to use for the User-Agent header.
 * Don't forget to terminate with \r\n
 */
static const char *header_user_agent = "Mozilla/5.0"
                                    " (X11; Linux x86_64; rv:3.10.0)"
                                    " Gecko/20191101 Firefox/63.0.1\r\n";

/*
 * parse_http_request: Takes in a string and converts into a HTTPRequest struct,
 * and also copies the uri to the location that c_uri points to. If the parse is
 * successful, it will return 0, otherwise, it will return -1.
 */
int parse_http_request(char* request_str, HTTPRequest* req, char* c_uri) {
    char method[MAXLINE], uri[MAXLINE], version[MAXLINE];

    sscanf(request_str, "%s %s %s", method, uri, version);
    strcpy(c_uri, uri);
    if (strcmp(method, "GET")) return -1;
    if (strncmp(uri, "http://", strlen("http://"))) return -1;
    char* start = uri + strlen("http://");
    char* mid = strstr(start, ":");
    char* end = strstr(start, "/");
    if (end == NULL) return -1;
    if (mid == NULL){
        *end = '\0';
        strcpy(req->hostname, start);
        strcpy(req->port,"80");
    }else{
        *mid = '\0';
        strcpy(req->hostname, start);
        mid++;
        *end = '\0';
        strcpy(req->port, mid);
    }
    *end = '/';
    strcpy(req->path, end);
    return 0;
}

/*
 * parse_request_header: Takes in a string and converts it into a RequestHeader struct,
 * If the parse is successful, it will return 0. If the header name is "Host", it will
 * not update the Request Header that hd points to, and will return 1. If the header name
 * is "User-Agent", "Connection" or "Proxy-Connection" or if the parse is unsuccessful, it
 * will not modify the contents that hd points to and will return -1.
 */
int parse_request_header(char* header_str, RequestHeader* hd) {
    char* mid = strstr(header_str, ": ");
    if (mid == NULL) return -1;
    *mid = '\0';

    if (strcmp(header_str, "Host") == 0) {
      *mid = ':';
      return 1;
    }
    if (strcmp(header_str, "User-Agent") == 0) return -1;
    if (strcmp(header_str, "Connection") == 0) return -1;
    if (strcmp(header_str, "Proxy-Connection") == 0) return -1;


    mid += 2;
    strcpy(hd->name, header_str);
    strcpy(hd->value, mid);
    return 0;
}

/*
 * request_web_server: Function that forwards the HTTP Request and the headers to the
 * server, returning the file descripter of the connection between the proxy and
 * the server
 */
int request_web_server(HTTPRequest* req, RequestHeader* hd, int num_headers) {
    int clientfd;
    char *host, *port, buf[MAXLINE];
    rio_t rio;

    host = req->hostname;
    port = req->port;
    clientfd = open_clientfd(host, port);
    rio_readinitb(&rio, clientfd);
    char* tmp = buf;
    sprintf(tmp, "GET %s HTTP/1.0\r\n", req->path);
    tmp = tmp + strlen(tmp);
    for (int i = 0; i < num_headers; i++){
        sprintf(tmp, "%s: %s", hd[i].name, hd[i].value);
        tmp = tmp + strlen(tmp);
    }
    sprintf(tmp, "\r\n");
    rio_writen(clientfd, buf, MAXLINE) ;
    return clientfd;
}

/*
 * serve: The main function that operates the proxy, it takes in the file descripter
 * of the connection between the client and the proxy. It reads an HTTP request from
 * the client, and then forward that request to the server, then writes the response from
 * the server back to the client. It maintains a cache so that it may not need to make
 * a request to the server again if the URI is requested recently.
 */
void serve(int connfd) {
    size_t n;
    char buf[MAXLINE], uri[MAXLINE];
    char cache_buf[MAX_OBJECT_SIZE];
    rio_t rio;
    HTTPRequest req;
    RequestHeader headers[MAX_NUM_HEADERS];

    //read and parse the HTTP Request
    rio_readinitb(&rio, connfd);
    if (rio_readlineb(&rio, buf, MAXLINE) <= 0) return;
    if (parse_http_request(buf, &req, uri) != 0) return;

    //initialize, read and parse the request headers
    int num_headers = 4;
    strcpy(headers[0].name, "Host");
    strcpy(headers[0].value, req.hostname);
    strcpy(headers[0].value,
           strcat(strcat(strcat(headers[0].value, ":"),req.port),"\r\n"));
    strcpy(headers[1].name, "User-Agent");
    strcpy(headers[1].value, header_user_agent);
    strcpy(headers[2].name, "Connection");
    strcpy(headers[2].value, "close\r\n");
    strcpy(headers[3].name, "Proxy-Connection");
    strcpy(headers[3].value, "close\r\n");
    rio_readlineb(&rio, buf, MAXLINE);
    while(strcmp(buf, "\r\n")) {
       int tmp = parse_request_header(buf, &headers[num_headers]);
        if (tmp == 1){
            char* mid = strstr(buf, ": ");
            mid += 2;
            strcpy(headers[0].value, mid);
        }else if (tmp == 0){
            num_headers++;
        }
        rio_readlineb(&rio, buf, MAXLINE);
    }

    //look up the URI in the cache
    char *cached_object = lookup_cache(uri, &n, true);
    if (cached_object != NULL){
        rio_writen(connfd, cached_object, n);
        free(cached_object);
        return;
    }

    //If not found in the cache, request from the server
    int web_connfd = request_web_server(&req, headers, num_headers);

    size_t cached_object_size = 0;
    bool caching = true;
    rio_readinitb(&rio, web_connfd);
    while ((n = rio_readnb(&rio, buf, MAXLINE)) > 0) {
       if (rio_writen(connfd, buf, n) < 0){
           close(web_connfd);
           return;
       }
       
       //copy the contents into the cache buffer
       if (caching && cached_object_size + n <= MAX_OBJECT_SIZE){
           memcpy(cache_buf+cached_object_size, buf, n);
           cached_object_size += n;
        }else{
           caching = false;
        }
    }
    close(web_connfd);

    //If object smaller than MAX_OBJECT_SIZE and not already in cache, insert
    //it into the cache
    if (caching && lookup_cache(uri, NULL, false) == NULL){
        char *content = malloc(cached_object_size);
        memcpy(content, cache_buf, cached_object_size);
        insert_cache(uri, content, cached_object_size);
    }
}

/*
 * sigpipe_handler: Signal Handler that does nothing when receiving
 * the signal SIGPIPE
 */
void sigpipe_handler(int sig)
{
  return;
}

/*
 * thread: Function that enables multi-threading for a concurrent proxy
 */
void *thread(void *vargp) {
    int connfd = *((int *)vargp);
    pthread_detach(pthread_self());
    free(vargp);
    signal(SIGPIPE, sigpipe_handler);
    serve(connfd);
    close(connfd);
    return NULL;
}

int main(int argc, char** argv) {
    int listenfd, *connfdp;
    socklen_t clientlen;
    struct sockaddr_storage clientaddr;
    pthread_t tid;

    cache = NULL;
    cache_size = 0;

    pthread_mutex_init(&cache_mutex, NULL);
    signal(SIGPIPE, sigpipe_handler);

    listenfd = open_listenfd(argv[1]);

    while (1) {
        clientlen = sizeof(struct sockaddr_storage);
        connfdp = malloc(sizeof(int));
        *connfdp = accept(listenfd, (SA *)&clientaddr, &clientlen);
        pthread_create(&tid, NULL, thread, connfdp);
    }
    exit(0);
}