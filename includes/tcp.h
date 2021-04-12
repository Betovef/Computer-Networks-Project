#ifndef TCP_PACKET_H
#define TCP_PACKET_H

enum{
    SYN,
    SYN_ACK,
    FIN,
    RESET,
    PUSH,
    URG,
    ACK
};

enum{
    TCP_MAX_PAYLOAD_SIZE = 12
};

typedef nx_struct tcp_segment{
    nx_uint8_t destPort;
    nx_uint8_t srcPort;
    nx_uint8_t seq;
    nx_uint8_t ACK;
    nx_uint8_t flags;

    nx_uint8_t lastACK;
    nx_uint8_t window;
    nx_uint8_t data[TCP_MAX_PAYLOAD_SIZE];

}tcp_segment;

#endif