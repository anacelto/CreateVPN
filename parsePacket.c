//
//  parsePacket.c
//  CreateVPN
//
//  Created by Oriol Marí Marqués on 22/02/2017.
//  Copyright © 2017 Oriol Marí Marqués. All rights reserved.
//

#include <arpa/inet.h>
#include <stdio.h>
#include <netinet/ip.h>
#include <syslog.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <time.h>


u_char parsePacket(uint8_t *packet, int n)

{
    
    char address[INET6_ADDRSTRLEN+1];
    
    struct ip *iph;
    
    iph = (struct ip *)packet;
    
    inet_ntop(AF_INET, &(iph->ip_src), address, INET_ADDRSTRLEN);
    
    syslog(LOG_WARNING, "LOG_WARNING %s\n", address);
    
    while(1) {
        syslog(LOG_WARNING, "THREAD %d %d\n", getpid(), n);
        sleep(2);
    }
    
    return iph->ip_ttl;
    
}

/*
 Simple udp server
 */

#define BUFLEN 512  //Max length of buffer
#define PORT 8888   //The port on which to listen for incoming data

void die(char *s)
{
    perror(s);
    exit(1);
}

int createSocket()
{
    struct sockaddr_in si_me, si_other;
    
    int s, i, slen = sizeof(si_other) , recv_len;
    char buf[BUFLEN];
    
    //create a UDP socket
    if ((s=socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) == -1)
    {
        die("socket");
    }
    
    // zero out the structure
    memset((char *) &si_me, 0, sizeof(si_me));
    
    si_me.sin_family = AF_INET;
    si_me.sin_port = htons(PORT);
    si_me.sin_addr.s_addr = htonl(INADDR_ANY);
    
    //bind socket to port
    if( bind(s , (struct sockaddr*)&si_me, sizeof(si_me) ) == -1)
    {
        die("bind");
    }
    
    //keep listening for data
    while(1)
    {
        syslog(LOG_WARNING, "Waiting for data...");
        fflush(stdout);
        
        //try to receive some data, this is a blocking call
        if ((recv_len = recvfrom(s, buf, BUFLEN, 0, (struct sockaddr *) &si_other, &slen)) == -1)
        {
            die("recvfrom()");
        }
        
        //print details of the client/peer
        syslog(LOG_WARNING, "Received packet from %s:%d\n", inet_ntoa(si_other.sin_addr), ntohs(si_other.sin_port));
        
        //now reply the client with the same data
        if (sendto(s, buf, recv_len, 0, (struct sockaddr*) &si_other, slen) == -1)
        {
            die("sendto()");
        }
    }
    
    //close(s);
    return 0;
}



