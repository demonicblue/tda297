/* =========================================================== *
 * 
 * =========================================================== */

#include "Timer.h"

#include "Rout.h"

module RoutC
{
  uses {
    interface Boot;
    interface Timer<TMilli> as PeriodTimer;
    
    interface Random;
    interface ParameterInit<uint16_t> as RandomSeed;
    interface Init as RandomInit;
    
    interface AMSend  as MessageSend;
    interface Packet  as MessagePacket;
    interface Receive as MessageReceive;

    interface Queue<rout_msg_t> as RouterQueue;

    interface SplitControl as MessageControl;
  }
  
}

implementation
{

  /* ==================== GLOBALS ==================== */
  /* Common message buffer*/
  message_t packet;
  rout_msg_t *message;

  /* Node to send messages to for routing towards sink */
  int16_t router = -1; 
  bool routerlessreported = FALSE;

  /* If node is looking for a new router */
  bool switchrouter = TRUE;

  /* If the message buffer is in use*/
  bool locked = FALSE;

  /* Battery level */
  uint16_t battery = 0;

  /* Is the node a cluster head */
  bool isClusterHead = FALSE;

  /* Collection of content */
  uint16_t summarizedContent = 0;

  /* Leader of the cluster group */
  int16_t myClusterHead = -1;

  /* ==================== HELPER FUNCTIONS ==================== */

  /* Returns a random number between 0 and n-1 (both inclusive) */
  uint16_t random(uint16_t n) {
      /* Modulu is a simple but bad way to do it! */
      return (call Random.rand16()) % n;
  }

  bool isSink() {
    return TOS_NODE_ID == SINKNODE;
  }

  int16_t distanceBetweenXY(int16_t ax,int16_t ay,int16_t bx,int16_t by) {
    return (bx - ax) * (bx-ax) + (by - ay) * (by-ay);
  }

  int16_t distanceBetween(int16_t aid,uint16_t bid) {
    int16_t ax = aid % COLUMNS;
    int16_t ay = aid / COLUMNS;
    int16_t bx = bid % COLUMNS;
    int16_t by = bid / COLUMNS;
    return distanceBetweenXY(ax, ay, bx, by);
  }
  
  int16_t distance(int16_t id) {
    return distanceBetween(SINKNODE, id);
  }
  
  char *messageTypeString(int16_t type) {
    switch(type) {
    case TYPE_ANNOUNCEMENT:
      return "ANNOUNCEMENT";
    case TYPE_CONTENT:
      return "CONTENT";
    default:
      return "Unknown";
    }
  }

  /* Select cluster heads in rotational order based on node id to achieve a more even distribution */
  void selectHeads(uint32_t roundcounter) {
    /*if (random(100) < 50) {
      isClusterHead = TRUE;
      dbg("Cluster", "Cluster: I am a head\n");
    } else {
      isClusterHead = FALSE;
    }*/
    if(TOS_NODE_ID%5 == ((roundcounter/ROUNDS)/2)%5) {
      isClusterHead = TRUE;
      dbg("Cluster", "Cluster: I am a head\n");
    } else {
      isClusterHead = FALSE;
    }
    
  }

#define dbgMessageLine(channel,str,mess) dbg(channel,"%s{%d, %s, %d}\n", str, mess->from, messageTypeString(mess->type),mess->seq);
#define dbgMessageLineInt(channel,str1,mess,str2,num) dbg(channel,"%s{%d, %s, %d}%s%d\n", str1, mess->from, messageTypeString(mess->type),mess->seq,str2,num);

  /* ==================== STARTUP ==================== */

  void startnode() {
    battery = BATTERYSTART;
    call PeriodTimer.startPeriodic(PERIOD);
    selectHeads(0);

  }

  void stopnode() {
    battery = 0;
    call PeriodTimer.stop();
  }

  event void Boot.booted() {
    call RandomInit.init();
    call MessageControl.start();
    message = (rout_msg_t*)call MessagePacket.getPayload(&packet, sizeof(rout_msg_t));
  }

  event void MessageControl.startDone(error_t err) {
    if (err == SUCCESS) {
      startnode();
    } else {
      call MessageControl.start();
    }
  }

  event void MessageControl.stopDone(error_t err) {
    ;
  }

  /* ==================== BATTERY ==================== */

  /* Returns whether battery has run out */
  uint16_t batteryEmpty() {
    return USEBATTERY && battery == 0;
  }
  
  /**/
  void batteryCheck() {
    if(batteryEmpty()) {
      dbg("Battery","Battery: Node ran out of battery\n");
      stopnode();
    }
  }

  /* Uses the stated level of battery. 
   * Returns wether it was enough or not. 
   * Shuts the node down if battery is emptied
   */
  bool batteryUse(uint16_t use) {
    bool send = (use <= battery);
    if(battery == 0) {
      return FALSE;
    }
    if(send) {
      battery -= use;
      dbg("BatteryUse","BatteryUse: Decreased by %d down to %d\n",use,battery);
    } else {
      battery = 0;
      batteryCheck();
      dbg("BatteryUse","BatteryUse: Ran out when trying to send\n");
    }
    return send;
  }

  uint16_t batteryRequiredForSend(am_addr_t receiver) {
    if(receiver == AM_BROADCAST_ADDR) {
      return MAXDISTANCE;
    } else {
      return distanceBetween(TOS_NODE_ID,receiver);
    }
  }

  /* Uses up battery for sending a message to receiver and returns whether
   * enough battery was left to complete the send. */
  bool batteryUseForSend(am_addr_t receiver) {
    if(USEBATTERY) {
      return batteryUse(batteryRequiredForSend(receiver));
    } else {
      return TRUE;
    }
  }

  /* ==================== ROUTING ==================== */

  void sendMessage(am_addr_t receiver) {
    if(!batteryUseForSend(receiver)) {
      return;
    }
    if (call MessageSend.send(receiver, &packet, sizeof(rout_msg_t)) == SUCCESS) {
      locked = TRUE;
      
      switch(message->type) {
      case TYPE_ANNOUNCEMENT:
        dbgMessageLine("Announcement","Announcement: Sending message ",message);
        break;
      case TYPE_ANNOUNCEMENT_HEAD:
        dbgMessageLine("Announcement","Announcement: Sending message ",message);
        break;
      case TYPE_CONTENT:
        dbgMessageLineInt("Content","Content: Sending message ",message," via ",receiver);
        break;
      case TYPE_CONTENT_HEAD:
        dbgMessageLineInt("Content","Content: Sending message ",message," via ",receiver);
        break;
      default:
        dbg("Error","ERROR: Unknown message type");
      }
    } else {
    dbg("Error","ERROR: MessageSend failed");
    }
    batteryCheck();
  }

  void rout() {
    if(call RouterQueue.empty()) {
      dbg("RoutDetail", "Rout: Rout called with empty queue\n");
    } else if(locked) {
      dbg("RoutDetail", "Rout: Message is locked.\n");
    } else if(batteryEmpty()) {
      dbg("RoutDetail", "Rout: Battery is empty.\n");
    } else {
      am_addr_t receiver;
      bool send = FALSE;
      rout_msg_t m = call RouterQueue.head();
      uint8_t type = m.type;
      dbg("RoutDetail", "Rout: Message will be sent.\n");
      switch(type) {
      case TYPE_ANNOUNCEMENT:
      case TYPE_ANNOUNCEMENT_HEAD:
        receiver = AM_BROADCAST_ADDR;
        send = TRUE;
        break;
      /* When a normal node sends a message that hasnt gone through a cluster head, it is TYPE_CONTET */  
      case TYPE_CONTENT:
        if(router == -1) {
          dbg("RoutDetail", "Rout: No router.\n");
          if(!routerlessreported) {
            dbg("Rout", "Rout: No router to send to\n");
            routerlessreported = TRUE;
          }
        } else {
          /* Routes to closest cluster head, if there is none, use normal route */
          if(myClusterHead == -1) {
            receiver = router;
          } else {
            receiver = myClusterHead;
          }
          send = TRUE;
        }
        break;
      /* When a cluster head sends a message it uses the normal route, same as if clusters werent used. */
      case TYPE_CONTENT_HEAD:
        if(router == -1) {
          dbg("RoutDetail", "Rout: No router.\n");
          if(!routerlessreported) {
            dbg("Rout", "Rout: No router to send to\n");
            routerlessreported = TRUE;
          }
        } else {
          receiver = router;
          send = TRUE;
        }
        break;
      default:
        dbg("Error", "ERROR: Unknown message type %d\n", type);
    }
    if(send) {
      *message = call RouterQueue.dequeue();
      sendMessage(receiver);
    }
    }
  }

  void routMessage() {
    if(call RouterQueue.enqueue(*message) != SUCCESS) {
      dbgMessageLine("Rout", "Rout: queue full, message dropped:", message);
    }
    /* Stupid way to put in front of queue */
    if(message->type == TYPE_ANNOUNCEMENT) {
      rout_msg_t m = call RouterQueue.head();
      while(m.type != TYPE_ANNOUNCEMENT) {
  m = call RouterQueue.dequeue();
  call RouterQueue.enqueue(m);
  m = call RouterQueue.head();
      }
    }
    rout();
  }

  /* ==================== ANNOUNCEMENT ==================== */

  /*
   * Here is what is sent in an announcement
   */
  void sendAnnounce() {
    message->from = TOS_NODE_ID;       /* The ID of the node */
    if(battery <= MAXDISTANCE)         /* Don't announce if battery is low */
      return;

    if(isClusterHead)                  /* Announce as cluster head */
      message->type = TYPE_ANNOUNCEMENT_HEAD;
    else
      message->type = TYPE_ANNOUNCEMENT;
    routMessage();
  }
  
  /*
   * This it what a node does when it gets an announcement from
   * another node. Here is where the node chooses which node to use as
   * its router.
   */
  void announceReceive(rout_msg_t *mess) {
    int16_t myDistance;
    int16_t annDistance;
    int16_t routerDistance;
    int16_t currentCost;
    int16_t annCost;
    int16_t annNode;
    int16_t currentNode;
    int16_t routerFirst;

   if(switchrouter) {
      /* We need updated router information */
      switchrouter = FALSE;
      router = -1;
      myClusterHead = -1;
    }


      myDistance   =  distance(TOS_NODE_ID);
      annDistance  =  distance(mess->from);
      
      if(router == -1 && myDistance > annDistance) /* Choose first node which is closer to the sink than us */
      {
        router = mess->from;
      } else if(router != -1)  /* If we have a router */
      {
        routerDistance    = distance(router);
        currentCost   = batteryRequiredForSend(router);
        annCost     = batteryRequiredForSend(mess->from);
        //if the distance of the current route is less than or equal to the current
        //route and the battery cost is less than or or equal, then chose the new
        // route.
        if(routerDistance >= annDistance && annCost <= currentCost){
          router = mess->from;
        }
      }

    /* Run this if normal node, ie not cluster head */
    if(!isClusterHead) {
    
      /* Chooses the closest cluster head as it's cluster head */
      if(mess->type == TYPE_ANNOUNCEMENT_HEAD) {
        if(myClusterHead == -1) {
          myClusterHead = mess->from;
          dbg("Cluster", "Cluster: Chose %d as my head\n", myClusterHead);
        } 
        annNode     = distanceBetween(TOS_NODE_ID, mess->from);
        currentNode = distanceBetween(TOS_NODE_ID, myClusterHead);
        if (annNode <= currentNode) {
          myClusterHead = mess->from;
        }
      }
    }
  }

  /* ==================== CONTENT ==================== */
  
  void sendContent() {
    static uint32_t sequence = 0;

    if(isClusterHead) { /* Cluster head collects sensor data instead of sending it */
      summarizedContent++;
      return;
    }
    message->from    = TOS_NODE_ID;       /* The ID of the node */
    message->type    = TYPE_CONTENT;
    message->content = 1;
    message->seq     = sequence++;
    routMessage();
    switchrouter = TRUE; /* Ready for another router round */
  }

  /* Cluster heads forwards summarized data */
  void sendSummarized() {
    static uint32_t sequence = 0; //this is iniitialized in sendContent() as well and set to 0. weird?
    message->from    = TOS_NODE_ID;       /* The ID of the node */
    message->type    = TYPE_CONTENT_HEAD; /* Changed type so we know it is a summarized message from a head */
    message->content = summarizedContent;
    message->seq     = sequence++;
    summarizedContent = 0; //reset when summarized content has been sent.
    routMessage();
    switchrouter = TRUE; /* Ready for another router round */
  }


  void contentReceive(rout_msg_t *mess) {
    if(isClusterHead) { /* Cluster head collects data ans summarizes instead of immedietly forwarding */
      summarizedContent++;
    } else {
      if(call RouterQueue.enqueue(*mess) == SUCCESS) {
        dbg("RoutDetail", "Rout: Message from %d enqueued\n", mess-> from);
      } else {
        dbgMessageLine("Rout", "Rout: queue full, message dropped:", mess);
      }
      rout();
    }
  }

  /*
   * This is what the sink does when it gets content:
   * It just collects it.
   */
  void contentCollect(rout_msg_t *mess) {
    static uint16_t collected = 0;
    if(mess->content > 0) {
      collected += mess->content;
    }
    dbg("Sink", "Sink: Have now collected %d pieces of information\n", collected);
  }

  /* ==================== EVENT CENTRAL ==================== */

  /* This is what drives the rounds
   * We assume that the nodes are synchronized
   */
  event void PeriodTimer.fired() {
    static uint32_t roundcounter = 0;
    if(batteryEmpty()) {
      return;
    }

    dbg("Event","--- EVENT ---: Timer @ round %d\n",roundcounter);
    switch(roundcounter % ROUNDS) {
    case ROUND_ANNOUNCEMENT: /* Announcement time */
      if(isSink()) {
        dbg("Round","========== Round %d ==========\n",roundcounter/ROUNDS);
      }
      if((roundcounter/ROUNDS)%2 == 0) /* Reselect cluster heads every other round */
        selectHeads(roundcounter);
      sendAnnounce();
      break;
    case ROUND_CONTENT: /* Message time */
      if(!isSink()) {
        sendContent();
      }
      break;
    case ROUND_CLUSTER: /* Cluster head sends data */
      if(!isSink() && isClusterHead) {
        sendSummarized();
      }
      break;
    default:
      dbg("Error", "ERROR: Unknown round %d\n", roundcounter);
    }
    roundcounter++;
  }
  
  event message_t* MessageReceive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    rout_msg_t* mess = (rout_msg_t*)payload;
    if(batteryEmpty()) {
      return bufPtr;
    }

    dbgMessageLine("Event","--- EVENT ---: Received ",mess);
    switch(mess->type) {
    case TYPE_ANNOUNCEMENT:
      dbgMessageLine("Announcement","Announcement: Received ",mess);
      announceReceive(mess);
      break;
    case TYPE_ANNOUNCEMENT_HEAD:
      dbgMessageLine("Announcement","Announcement_head: Received ",mess);
      announceReceive(mess);
      break;
    case TYPE_CONTENT:
    case TYPE_CONTENT_HEAD:
      dbgMessageLine("Content","Content: Received ",mess);
      if(isSink()) {
  contentCollect(mess);
      } else {
  contentReceive(mess);
      }
      break;
    default:
      dbg("Error", "ERROR: Unknown message type %d\n",mess->type);
    }

    /* Because of lack of memory in sensor nodes TinyOS forces us to
     * maintain an equilibrium by givin a buffer back for every
     * message we get. In this case we give it back immediately.  
     * So do not try to save a pointer somewhere to this or the
     * payload */
    return bufPtr;
  }
  
  /* Message has been sent and we are ready to send another one. */
  event void MessageSend.sendDone(message_t* bufPtr, error_t error) {
    dbgMessageLine("Event","--- EVENT ---: sendDone ",message);
    if (&packet == bufPtr) {
      locked = FALSE;
      rout();
    } else {
      dbg("Error", "ERROR: Got sendDone for another message\n");
    }
  }
  

}


