#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/TCPheader.h"
#include <Timer.h>

module TransportP{
	
	uses interface Timer<TMilli> as T_timer;

	uses interface SimpleSend;
	uses interface Forwarding;

	uses interface List<socket_t> as SocketList;
	uses interface Queue<pack> as packQ;

	uses interface RoutingTable;

	provides interface Transport;
}
implementation{

	socket_t getSocket(uint8_t destPort, uint8_t srcPort);
	socket_t getServerSocket(uint8_t destPort);


	event void T_timer.fired(){
		pack myMsg = call packQ.head();
		pack sendPack;

		tcp_pack* TCPpack = (tcp_pack *)(myMsg.payload);
		socket_t mySocket = getSocket(TCPpack->srcPort, TCPpack->destPort);
		
		if(mySocket.dest.port){
			call SocketList.pushback(mySocket);

			call Transport.makePack(&sendPack, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, (uint8_t *)TCPpack, PACKET_MAX_PAYLOAD_SIZE);
			call Forwarding.send(mySocket.dest.addr, &sendPack);

		}
	

	}

	socket_t getSocket(uint8_t destPort, uint8_t srcPort){
		socket_t mySocket;
		uint32_t i = 0;
		uint32_t size = call SocketList.size();
		
		for (i = 0; i < size; i++){
			mySocket = call SocketList.get(i);
			if(mySocket.dest.port == srcPort && mySocket.src.port == destPort){
				return mySocket;
			}
		}

	}

	socket_t getServerSocket(uint8_t destPort){
		socket_t mySocket;
		bool foundSocket;
		uint16_t i = 0;
		uint16_t size = call SocketList.size();
		
		for(i = 0; i < size; i++){
			mySocket = call SocketList.get(i);
			if(mySocket.src.port == destPort && mySocket.state == LISTEN){
				return mySocket;
			}
		}
		dbg(TRANSPORT_CHANNEL, "Socket not found. \n");
	}

	command error_t Transport.connect(socket_t fd){
		pack myMsg;
		tcp_pack* TCPpack;
		socket_t mySocket = fd;
		
		TCPpack = (tcp_pack*)(myMsg.payload);
		TCPpack->destPort = mySocket.dest.port;
		TCPpack->srcPort = mySocket.src.port;
		TCPpack->ACK = 0;
		TCPpack->seq = 1;
		TCPpack->flags = SYN_FLAG;

		call Transport.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, (void *)TCPpack, PACKET_MAX_PAYLOAD_SIZE);
		mySocket.state = SYN_SENT;

		dbg(ROUTING_CHANNEL, "Node %u State is %u \n", mySocket.src.addr, mySocket.state);

		dbg(ROUTING_CHANNEL, "CLIENT TRYING \n");

		call Forwarding.send(mySocket.dest.addr, &myMsg);

}	
	
	void connectDone(socket_t fd){
		pack myMsg;
		tcp_pack* TCPpack;
		socket_t mySocket = fd;
		uint16_t i = 0;

	
		TCPpack = (tcp_pack*)(myMsg.payload);
		TCPpack->destPort = mySocket.dest.port;
		TCPpack->srcPort = mySocket.src.port;
		TCPpack->flags = DATA_FLAG;
		TCPpack->seq = 0;

		i = 0;
		while(i < TCP_PACKET_MAX_PAYLOAD_SIZE && i <= mySocket.effectiveWindow){
			TCPpack->payload[i] = i;
			i++;
		}

		TCPpack->ACK = i;
		call Transport.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, (void*)TCPpack, PACKET_MAX_PAYLOAD_SIZE);

		dbg(ROUTING_CHANNEL, "Node %u State is %u \n", mySocket.src.addr, mySocket.state);

		dbg(ROUTING_CHANNEL, "SERVER CONNECTED\n");

		call packQ.enqueue(myMsg);

		call T_timer.startOneShot(9999);

		call Forwarding.send(mySocket.dest.addr, &myMsg);

}	

	command error_t Transport.receive(pack* msg){
		uint8_t srcPort = 0;
		uint8_t destPort = 0;
		uint8_t seq = 0;
		uint8_t lastAck = 0;
		uint8_t flags = 0;
		uint16_t bufflen = TCP_PACKET_MAX_PAYLOAD_SIZE;
		uint16_t i = 0;
		uint16_t j = 0;
		uint32_t key = 0;
		socket_t mySocket;
		tcp_pack* myMsg = (tcp_pack *)(msg->payload);


		pack myNewMsg;
		tcp_pack* TCPpack;

		srcPort = myMsg->srcPort;
		destPort = myMsg->destPort;
		seq = myMsg->seq;
		lastAck = myMsg->ACK;
		flags = myMsg->flags;

		if(flags == SYN_FLAG || flags == SYN_ACK_FLAG || flags == ACK_FLAG){

			if(flags == SYN_FLAG){
				dbg(TRANSPORT_CHANNEL, "Got SYN! \n");
				mySocket = getServerSocket(destPort);
				if(mySocket.state == LISTEN){
					mySocket.state = SYN_RCVD;
					mySocket.dest.port = srcPort;
					mySocket.dest.addr = msg->src;
					call SocketList.pushback(mySocket);
				
					TCPpack = (tcp_pack *)(myNewMsg.payload);
					TCPpack->destPort = mySocket.dest.port;
					TCPpack->srcPort = mySocket.src.port;
					TCPpack->seq = 1;
					TCPpack->ACK = seq + 1;
					TCPpack->flags = SYN_ACK_FLAG;
					dbg(TRANSPORT_CHANNEL, "Sending SYN ACK! \n");
					call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, (void*)TCPpack, PACKET_MAX_PAYLOAD_SIZE);
					call Forwarding.send(mySocket.dest.addr, &myNewMsg);
				}
			}

			else if(flags == SYN_ACK_FLAG){
				dbg(TRANSPORT_CHANNEL, "Got SYN ACK! \n");
				mySocket = getSocket(destPort, srcPort);
				mySocket.state = ESTABLISHED;
				call SocketList.pushback(mySocket);

				TCPpack = (tcp_pack*)(myNewMsg.payload);
				TCPpack->destPort = mySocket.dest.port;
				TCPpack->srcPort = mySocket.src.port;
				TCPpack->seq = 1;
				TCPpack->ACK = seq + 1;
				TCPpack->flags = ACK_FLAG;
				dbg(TRANSPORT_CHANNEL, "SENDING ACK \n");
				call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, (void*)TCPpack, PACKET_MAX_PAYLOAD_SIZE);
				call Forwarding.send(mySocket.dest.addr, &myNewMsg);

				connectDone(mySocket);
			}

			else if(flags == ACK_FLAG){
				dbg(TRANSPORT_CHANNEL, "GOT ACK \n");
				mySocket = getSocket(destPort, srcPort);
				if(mySocket.state == SYN_RCVD){
					mySocket.state = ESTABLISHED;
					call SocketList.pushback(mySocket);
				}
			}
		}

		if(flags == DATA_FLAG || flags == DATA_ACK_FLAG){

			if(flags == DATA_FLAG){
				mySocket = getSocket(destPort, srcPort);
				if(mySocket.state == ESTABLISHED){
					TCPpack = (tcp_pack*)(myNewMsg.payload);
					if(myMsg->payload[0] != 0){
						i = mySocket.lastRcvd + 1;
						j = 0;
						while(j < myMsg->ACK){
							mySocket.rcvdBuff[i] = myMsg->payload[j];
							mySocket.lastRcvd = myMsg->payload[j];
							i++;
							j++;
						}
					}else{
						i = 0;
						while(i < myMsg->ACK){
							mySocket.rcvdBuff[i] = myMsg->payload[i];
							mySocket.lastRcvd = myMsg->payload[i];
							i++;
						}
					}

				mySocket.effectiveWindow = SOCKET_BUFFER_SIZE - mySocket.lastRcvd + 1;
				call SocketList.pushback(mySocket);
			
				TCPpack->destPort = mySocket.dest.port;
				TCPpack->srcPort = mySocket.src.port;
				TCPpack->seq = seq;
				TCPpack->ACK = seq + 1;
				TCPpack->lastACK = mySocket.lastRcvd;
				TCPpack->window = mySocket.effectiveWindow;
				TCPpack->flags = DATA_ACK_FLAG;
				dbg(TRANSPORT_CHANNEL, "SENDING DATA ACK FLAG\n");
				call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0 , (void*)TCPpack, PACKET_MAX_PAYLOAD_SIZE);
				call Forwarding.send(mySocket.dest.addr, &myNewMsg);
				}
			
			} else if (flags == DATA_ACK_FLAG){
				mySocket = getSocket(destPort, srcPort);
				if(mySocket.state == ESTABLISHED){
					if(myMsg->window != 0 && myMsg->lastACK != mySocket.effectiveWindow){
						TCPpack = (tcp_pack*)(myNewMsg.payload);
						i = myMsg->lastACK + 1;
						j = 0;
						
						while(j < myMsg->window && j < TCP_PACKET_MAX_PAYLOAD_SIZE && i <= mySocket.effectiveWindow){
							TCPpack->payload[j] = i;
							i++;
							j++;
						}
					
						call SocketList.pushback(mySocket);
						TCPpack->flags = DATA_FLAG;
						TCPpack->destPort = mySocket.dest.port;
						TCPpack->srcPort = mySocket.src.port;
						TCPpack->ACK = i - 1 - myMsg->lastACK;
						TCPpack->seq = lastAck;
						call Transport.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, (void*)TCPpack, PACKET_MAX_PAYLOAD_SIZE);

						call packQ.dequeue();
						call packQ.enqueue(myNewMsg);
						dbg(TRANSPORT_CHANNEL, "SENDING NEW DATA \n");
						call Forwarding.send(mySocket.dest.addr, &myNewMsg);
					}else{

						mySocket.state = FIN_FLAG;
						call SocketList.pushback(mySocket);
						TCPpack = (tcp_pack*)(myNewMsg.payload);
						TCPpack->destPort = mySocket.dest.port;
						TCPpack->srcPort = mySocket.src.port;
						TCPpack->seq = 1;
						TCPpack->ACK = seq + 1;
						TCPpack->flags = FIN_FLAG;
						call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, (void*)TCPpack, PACKET_MAX_PAYLOAD_SIZE);
						call Forwarding.send(mySocket.dest.addr, &myNewMsg);

					}
				}
			}
		}
		if(flags == FIN_FLAG || flags == FIN_ACK){
			if(flags == FIN_FLAG){
				dbg(TRANSPORT_CHANNEL, "GOT FIN FLAG \n");
				mySocket = getSocket(destPort, srcPort);
				mySocket.state = CLOSED;
				mySocket.dest.port = srcPort;
				mySocket.dest.addr = msg->src;
		
				TCPpack = (tcp_pack *)(myNewMsg.payload);
				TCPpack->destPort = mySocket.dest.port;
				TCPpack->srcPort = mySocket.src.port;
				TCPpack->seq = 1;
				TCPpack->ACK = seq + 1;
				TCPpack->flags = FIN_ACK;
				
				call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, (void*)TCPpack, PACKET_MAX_PAYLOAD_SIZE);
				call Forwarding.send(mySocket.dest.addr, &myNewMsg);
			}
			if(flags == FIN_ACK){
				dbg(TRANSPORT_CHANNEL, "GOT FIN ACK \n");
				mySocket = getSocket(destPort, srcPort);
				mySocket.state = CLOSED;
			}
		}
}

	command void Transport.setTestServer(){

		socket_t mySocket;
		socket_addr_t myAddr;
		
		myAddr.addr = TOS_NODE_ID;
		myAddr.port = 123;
		
		mySocket.src = myAddr;
		mySocket.state = LISTEN;
	
		call SocketList.pushback(mySocket);
	}
	command void Transport.setTestClient(){

		socket_t mySocket;
		socket_addr_t myAddr;

		myAddr.addr = TOS_NODE_ID;
		myAddr.port = 200;

		mySocket.dest.port = 123;
		mySocket.dest.addr = 1;
	
		mySocket.src = myAddr;
		
		call SocketList.pushback(mySocket);
		call Transport.connect(mySocket);
	}
	command void Transport.makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
		Package->src = src;
		Package->dest = dest;
		Package->TTL = TTL;
		Package->seq = seq;
		Package->protocol = protocol;
		memcpy(Package->payload, payload, length);
}
}