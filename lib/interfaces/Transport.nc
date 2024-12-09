#include "../includes/packet.h"
#include "../includes/socket.h"
#include "../includes/TCPheader.h"

interface Transport{

	command error_t connect(socket_t fd);
	command void setTestServer();
	command void setTestClient(uint8_t destination);
	command void get(tcp_pack* payload);

}