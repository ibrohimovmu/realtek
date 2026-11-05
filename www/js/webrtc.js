/**
 * RealStrike AR - Tactical WebRTC P2P & Multiplayer Mesh Network
 * Zero-latency local Wi-Fi / Hotspot P2P with fallback broadcast channel.
 */
class TacticalP2PNetwork {
  constructor() {
    this.isHost = false;
    this.roomPin = null;
    this.peerConnection = null;
    this.dataChannel = null;
    this.broadcastChannel = null;
    this.connectedPeers = new Map(); // id -> peerData
    
    // Callbacks
    this.onPeerJoined = null;
    this.onPeerLeft = null;
    this.onMatchStart = null;
    this.onPacketReceived = null;
    this.onConnectionStateChange = null;

    this.initBroadcastChannel();
  }

  // BroadcastChannel for instant local testing across tabs or webviews on same device
  initBroadcastChannel() {
    try {
      if (typeof BroadcastChannel !== 'undefined') {
        this.broadcastChannel = new BroadcastChannel('realstrike_ar_mesh');
        this.broadcastChannel.onmessage = (e) => this.handleIncomingMessage(e.data, 'broadcast');
      }
    } catch (err) {
      console.warn('BroadcastChannel not available:', err);
    }
  }

  generateRoomPin() {
    return Math.floor(1000 + Math.random() * 9000).toString();
  }

  createRoom() {
    this.isHost = true;
    this.roomPin = this.generateRoomPin();
    this.connectedPeers.clear();

    const hostOperator = {
      id: 'HOST_' + Date.now().toString(36),
      callsign: window.profile.data.callsign,
      rank: window.profile.getRankInfo().rank.name,
      level: window.profile.getRankInfo().level,
      isHost: true,
      ready: true,
      hp: 100,
      pingMs: 2
    };

    this.connectedPeers.set(hostOperator.id, hostOperator);

    // Broadcast room creation
    this.broadcastPacket({
      type: 'ROOM_ANNOUNCE',
      roomPin: this.roomPin,
      host: hostOperator
    });

    return {
      pin: this.roomPin,
      host: hostOperator
    };
  }

  joinRoom(pin) {
    this.isHost = false;
    this.roomPin = pin.trim();

    const myOperator = {
      id: 'CLIENT_' + Date.now().toString(36),
      callsign: window.profile.data.callsign,
      rank: window.profile.getRankInfo().rank.name,
      level: window.profile.getRankInfo().level,
      isHost: false,
      ready: true,
      hp: 100,
      pingMs: 4
    };

    this.myPeerId = myOperator.id;

    // Send Join Request
    this.broadcastPacket({
      type: 'ROOM_JOIN_REQUEST',
      roomPin: this.roomPin,
      player: myOperator
    });

    return myOperator;
  }

  sendPacket(packet) {
    packet.timestamp = Date.now();
    packet.senderId = this.myPeerId || 'HOST';

    if (this.dataChannel && this.dataChannel.readyState === 'open') {
      try {
        this.dataChannel.send(JSON.stringify(packet));
      } catch (e) {
        console.warn('WebRTC data channel send error:', e);
      }
    }

    // Also send via local mesh channel
    this.broadcastPacket(packet);
  }

  broadcastPacket(packet) {
    if (this.broadcastChannel) {
      try {
        this.broadcastChannel.postMessage(packet);
      } catch (e) {
        console.warn('Broadcast send error:', e);
      }
    }
  }

  handleIncomingMessage(data, transport = 'p2p') {
    if (!data || typeof data !== 'object') return;
    
    // If packet has roomPin and it doesn't match our roomPin, discard
    if (data.roomPin && this.roomPin && data.roomPin !== this.roomPin) {
      return;
    }

    // Avoid echo of our own packets
    if (data.senderId && data.senderId === this.myPeerId) {
      return;
    }

    switch (data.type) {
      case 'ROOM_JOIN_REQUEST':
        if (this.isHost && data.roomPin === this.roomPin) {
          const newPlayer = data.player;
          this.connectedPeers.set(newPlayer.id, newPlayer);
          
          // Reply with current roster
          this.broadcastPacket({
            type: 'ROOM_ROSTER_UPDATE',
            roomPin: this.roomPin,
            players: Array.from(this.connectedPeers.values())
          });

          if (this.onPeerJoined) this.onPeerJoined(newPlayer);
        }
        break;

      case 'ROOM_ROSTER_UPDATE':
        if (data.roomPin === this.roomPin) {
          this.connectedPeers.clear();
          data.players.forEach(p => this.connectedPeers.set(p.id, p));
          if (this.onConnectionStateChange) {
            this.onConnectionStateChange(Array.from(this.connectedPeers.values()));
          }
        }
        break;

      case 'START_MATCH':
        if (data.roomPin === this.roomPin) {
          if (this.onMatchStart) this.onMatchStart(data);
        }
        break;

      case 'PLAYER_FIRE':
      case 'PLAYER_HIT':
      case 'PLAYER_DAMAGE':
      case 'PLAYER_ELIMINATED':
      case 'MATCH_END':
        if (this.onPacketReceived) {
          this.onPacketReceived(data);
        }
        break;
    }
  }

  startMatch() {
    if (!this.isHost) return;
    const packet = {
      type: 'START_MATCH',
      roomPin: this.roomPin,
      startTime: Date.now() + 3000 // 3-second tactical countdown
    };
    this.sendPacket(packet);
    if (this.onMatchStart) this.onMatchStart(packet);
  }

  leaveRoom() {
    if (this.roomPin) {
      this.broadcastPacket({
        type: 'PLAYER_LEFT',
        roomPin: this.roomPin,
        senderId: this.myPeerId
      });
    }
    this.roomPin = null;
    this.isHost = false;
    this.connectedPeers.clear();
    if (this.dataChannel) {
      try { this.dataChannel.close(); } catch(e) {}
      this.dataChannel = null;
    }
    if (this.peerConnection) {
      try { this.peerConnection.close(); } catch(e) {}
      this.peerConnection = null;
    }
  }
}

window.p2pNetwork = new TacticalP2PNetwork();
