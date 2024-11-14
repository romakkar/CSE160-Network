#include "../includes/packet.h"
#include "../includes/socket.h"

interface Transport{

	command error_t connect(socket_t fd);
	command error_t receive(pack* package);
	command void setTestServer();
	command void setTestClient();
	command void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

}