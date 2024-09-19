uses interface Timer<TMilli> as <timerName>

when sending one packet
call <timerName>.startOneShot(<time>)

event void <timerName>.fired(){
    makePack()
    call SimpleSend.send(pack, AM_BROADCAST_ADDR)
    beaconSeqNum++;
}

eventRecieved.receive(){
    if message->protocol == PROTOCOL_BEACON_UP{
        makePack()
        call SimpleSend.send(pack, message.source || AM_BROADCAST_ADDR)
        beaconSeqNum++;
    }
}