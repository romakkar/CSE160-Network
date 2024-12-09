#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/TCPheader.h"
#include <Timer.h>

module TransportP{
	
	uses interface Timer<TMilli> as T_timer;

	uses interface Forwarding;

	uses interface List<socket_t> as SocketList;
	uses interface Queue<tcp_pack> as packQ;

	provides interface Transport;
}

implementation{

	socket_t getSocket(uint8_t destPort, uint8_t srcPort);
	socket_t getServerSocket(uint8_t destPort);
	tcp_pack current;
	tcp_pack* TCPpack;
	uint8_t port = 20;
	uint16_t seqNum; 
	pack sendPack; 

	void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, void* payload, uint8_t length) {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }
	event void T_timer.fired(){
		// current = call packQ.head(); //If the timer runs out then it will be calling the first packet
		// TCPpack = &current; //Assigned to the current packet
		// socket_t mySocket = getSocket(current.srcPort, current.destPort);
		
	}

	socket_t getSocket(uint8_t destPort, uint8_t srcPort){
		socket_t mySocket;
		uint32_t i = 0;
		uint32_t size = call SocketList.size();
		
		for (i = 0; i < size; i++){
			mySocket = call SocketList.get(i);
			if(mySocket.dest.port == srcPort && mySocket.src.port == destPort){
				call SocketList.remove(i);
				return mySocket;
			}
		}

	}

	socket_t getServerSocket(uint8_t destPort){
		socket_t mySocket;
		uint16_t i = 0;
		uint16_t size = call SocketList.size();
		
		for(i = 0; i < size; i++){
			mySocket = call SocketList.get(i);
			if((mySocket.src.port == destPort || destPort == 0) && mySocket.state == LISTEN){
				call SocketList.remove(i);
				return mySocket;
			}
		}
		dbg(TRANSPORT_CHANNEL, "Socket not found. \n");
	}

	command error_t Transport.connect(socket_t s){
		socket_t mySocket = s;
		
		TCPpack = &current; 

		TCPpack->destPort = mySocket.dest.port;
		TCPpack->srcPort = mySocket.src.port;
		TCPpack->ACK = 0;
		TCPpack->seq = 1;
		TCPpack->flags = SYN_FLAG;
		mySocket.state = SYN_SENT;
		call SocketList.pushback(mySocket);

		dbg(TRANSPORT_CHANNEL, "Node %u State is %u \n", mySocket.src.addr, mySocket.state);
		makePack(&sendPack, TOS_NODE_ID, mySocket.dest.addr, 20, PROTOCOL_TCP, seqNum, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
		call Forwarding.send(mySocket.dest.addr, sendPack);

	}
	
	void connectDone(socket_t s){
		socket_t mySocket = s;
		uint16_t i = 0;

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
	

		dbg(TRANSPORT_CHANNEL, "Node %u State is %u \n", mySocket.src.addr, mySocket.state);

		dbg(TRANSPORT_CHANNEL, "SERVER CONNECTED\n");

		call packQ.enqueue(*TCPpack);

		call T_timer.startOneShot(9999);
		makePack(&sendPack, TOS_NODE_ID, mySocket.dest.addr, 20, PROTOCOL_TCP, seqNum, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
		call Forwarding.send(mySocket.dest.addr, sendPack);

	}	




	command void Transport.get(tcp_pack* payload) {

		socket_t mySocket;
		uint16_t i = 0;
		uint16_t j = 0;
		dbg(TRANSPORT_CHANNEL, "Node %u received a TCP Packet. Destination Port: %u\nflag: %d\n", TOS_NODE_ID, payload->destPort, payload->flags);

		if (payload->flags == SYN_FLAG) {
			dbg(TRANSPORT_CHANNEL, "Got SYN! \n");
			mySocket = getServerSocket(payload->destPort);
			if(mySocket.state == LISTEN){
				mySocket.dest.port = payload->srcPort;
				mySocket.dest.addr = *(uint16_t*)(payload->payload);
				mySocket.state = SYN_RCVD;
				TCPpack = &current;
				TCPpack->destPort = mySocket.dest.port;
				TCPpack->srcPort = mySocket.src.port;
				TCPpack->flags = SYN_ACK_FLAG;
				TCPpack->ACK = TCPpack->seq + 1;
				TCPpack->seq = 1;

				makePack(&sendPack, TOS_NODE_ID, mySocket.dest.addr, 20, PROTOCOL_TCP, seqNum, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
				call Forwarding.send(mySocket.dest.addr, sendPack);
				call SocketList.pushback(mySocket);

				dbg(TRANSPORT_CHANNEL, "Send SYN-ACK\n");
			}
		}

		else if (payload->flags == SYN_ACK_FLAG) {
			mySocket = getSocket(payload->destPort, 0);
			dbg(TRANSPORT_CHANNEL, "Got SYN ACK!, STATE: %d \n", mySocket.state);
			if(mySocket.state == SYN_SENT){
				TCPpack = &current;
				mySocket.state = ESTABLISHED;
				mySocket.dest.port = payload->srcPort;
				call SocketList.pushback(mySocket);

				TCPpack->destPort = mySocket.dest.port;
				TCPpack->srcPort = mySocket.src.port;
				TCPpack->flags = ACK_FLAG;
				dbg(TRANSPORT_CHANNEL, "SENDING ACK, STATE: %d \n", mySocket.state);
				TCPpack->seq = 0;

				makePack(&sendPack, TOS_NODE_ID, mySocket.dest.addr, 20, PROTOCOL_TCP, seqNum, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
				call Forwarding.send(mySocket.dest.addr, sendPack);
			}
			// connectDone(mySocket);
		}

		else if (payload->flags == ACK_FLAG) {
			dbg(TRANSPORT_CHANNEL, "GOT ACK \n");
			mySocket = getSocket(payload->destPort, payload->srcPort);
			if (mySocket.state == SYN_RCVD) {
				mySocket.state = ESTABLISHED;
				mySocket.effectiveWindow = SOCKET_BUFFER_SIZE - mySocket.lastRcvd + 1;
				call SocketList.pushback(mySocket);
				TCPpack->destPort = mySocket.dest.port;
				TCPpack->srcPort = mySocket.src.port;
				TCPpack->flags = DATA_FLAG;
				TCPpack->ACK = i - 1 - payload->ACK;
				TCPpack->seq = payload->ACK;
				TCPpack->window = mySocket.effectiveWindow;
				*(TCPpack->payload) = 200;
				makePack(&sendPack, TOS_NODE_ID, mySocket.dest.addr, 20, PROTOCOL_TCP, seqNum, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
				dbg(TRANSPORT_CHANNEL, "SENDING NEW DATA: %d \n", mySocket.state);
				call Forwarding.send(mySocket.dest.addr, sendPack);
			}
		}

		else if (payload->flags == DATA_FLAG) {
			mySocket = getSocket(payload->destPort, payload->srcPort);
			TCPpack = &current;
			dbg(TRANSPORT_CHANNEL, "GOT data: %d \n", *(payload->payload));
			// if (mySocket.state == ESTABLISHED) {
			// 	if (payload->payload[0] != 0) {
			// 		i = mySocket.lastRcvd + 1;
			// 		j = 0;
			// 		while (j < payload->ACK) {
			// 			mySocket.rcvdBuff[i] = payload->payload[j];
			// 			mySocket.lastRcvd = payload->payload[j];
			// 			i++;
			// 			j++;
			// 		}
			// 	} else {
			// 		i = 0;
			// 		while (i < payload->ACK) {
			// 			mySocket.rcvdBuff[i] = payload->payload[i];
			// 			mySocket.lastRcvd = payload->payload[i];
			// 			i++;
			// 		}
			// 	}
			// }
			mySocket.effectiveWindow = SOCKET_BUFFER_SIZE - mySocket.lastRcvd + 1;
			call SocketList.pushback(mySocket);

			TCPpack->destPort = mySocket.dest.port;
			TCPpack->srcPort = mySocket.src.port;
			TCPpack->flags = DATA_ACK_FLAG;
			TCPpack->seq = 0;
			dbg(TRANSPORT_CHANNEL, "Sending DATA_ACK\n");
			makePack(&sendPack, TOS_NODE_ID, mySocket.dest.addr, 20, PROTOCOL_TCP, seqNum, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
			call Forwarding.send(mySocket.dest.addr, sendPack);
		}

		else if (payload->flags == DATA_ACK_FLAG) {
			mySocket = getSocket(payload->destPort, payload->srcPort);
			dbg(TRANSPORT_CHANNEL, "GOT DATA_ACK \n");
			if (mySocket.state == ESTABLISHED) {
				// if (payload->window != 0 && payload->ACK != mySocket.effectiveWindow) {
					TCPpack = &current;
					i = payload->ACK + 1;
					j = 0;

					while (j < payload->window && j < TCP_PACKET_MAX_PAYLOAD_SIZE && i <= mySocket.effectiveWindow) {
						TCPpack->payload[j] = i;
						i++;
						j++;
					}

					call SocketList.pushback(mySocket);

					TCPpack->destPort = mySocket.dest.port;
					TCPpack->srcPort = mySocket.src.port;
					TCPpack->flags = FIN_FLAG;
					TCPpack->ACK = i - 1 - payload->ACK;
					TCPpack->seq = payload->ACK;

					makePack(&sendPack, TOS_NODE_ID, mySocket.dest.addr, 20, PROTOCOL_TCP, seqNum, TCPpack, PACKET_MAX_PAYLOAD_SIZE);

					dbg(TRANSPORT_CHANNEL, "SENDING FIN \n");
					call Forwarding.send(mySocket.dest.addr, sendPack);
				// }
			}
		}

		else if (payload->flags == FIN_FLAG) {
			mySocket = getSocket(payload->destPort, payload->srcPort);
			dbg(TRANSPORT_CHANNEL, "GOT FIN\n");
			TCPpack = &current;
			TCPpack->destPort = mySocket.dest.port;
			TCPpack->srcPort = mySocket.src.port;
			TCPpack->flags = FIN_ACK;
			TCPpack->ACK = TCPpack->seq + 1;
			TCPpack->seq = 1;

			makePack(&sendPack, TOS_NODE_ID, mySocket.dest.addr, 20, PROTOCOL_TCP, seqNum, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
			call Forwarding.send(mySocket.dest.addr, sendPack);
			dbg(TRANSPORT_CHANNEL, "SENDING FIN_ACK\n");
		}

		else if (payload->flags == FIN_ACK) {
			dbg(TRANSPORT_CHANNEL, "GOT FIN_ACK \n");
			mySocket = getSocket(payload->destPort, payload->srcPort);
			TCPpack = &current;
			mySocket.state = LISTEN;
			mySocket.dest.port = 0;
			mySocket.dest.addr - 0;
			call SocketList.pushback(mySocket);
		}
	}

	command void Transport.setTestServer(){
		socket_t mySocket;
		socket_addr_t myAddr;
		
		myAddr.addr = TOS_NODE_ID;
		myAddr.port = port++;
		
		mySocket.src = myAddr;
		mySocket.state = LISTEN;
	
		call SocketList.pushback(mySocket);
	}
	command void Transport.setTestClient(uint8_t destination){

		socket_t mySocket;
		socket_addr_t myAddr;

		myAddr.addr = TOS_NODE_ID;
		myAddr.port = port++;

		mySocket.dest.port = 0;
		mySocket.dest.addr = destination;
	
		mySocket.src = myAddr;
		mySocket.state = SYN_SENT;
		
		call SocketList.pushback(mySocket);
		call Transport.connect(mySocket);
	}
}


