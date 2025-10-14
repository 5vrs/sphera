const express = require('express');
const playerApi = require('./playerApi');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const { initScheduler } = require('./scheduler');

const app = express();
const PORT = process.env.PORT || 5000;

// Create HTTP server and Socket.io instance
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.CLIENT_URL || "http://localhost:3000",
    methods: ["GET", "POST"]
  }
});

// Game rooms storage
const gameRooms = new Map();

// Middleware
app.use(express.json());
app.use(cors());

// Root route
app.get('/', (req, res) => {
  res.send('Server is running!');
});

// API routes
app.use('/api', playerApi);

// Socket.io connection handling
io.on('connection', (socket) => {
  console.log(`Player connected: ${socket.id}`);
  
  // Create a new game room
  socket.on('createGame', ({ playerName, playerData, selectedNfts }) => {
    // Generate a unique game code
    const gameCode = Math.random().toString(36).substring(2, 8).toUpperCase();
    const gameId = `game_${Date.now()}`;
    
    // Store game data
    gameRooms.set(gameCode, {
      id: gameId,
      code: gameCode,
      players: [
        {
          id: socket.id,
          name: playerName || `Player ${socket.id.substring(0, 4)}`,
          selectedNfts,
          ready: true,
          usedStats: []
        }
      ],
      rounds: [],
      currentRound: 0,
      status: 'waiting' // 'waiting', 'playing', 'completed'
    });
    
    // Join socket to room channel
    socket.join(gameCode);
    
    // Send game info back to creator
    socket.emit('gameCreated', { gameId, gameCode });
    console.log(`Game created: ${gameCode}`);
  });
  
  // Join an existing game
  socket.on('joinGame', ({ gameCode, playerName, playerData, selectedNfts }) => {
    const room = gameRooms.get(gameCode);
    
    if (!room) {
      socket.emit('gameError', { error: 'Game not found' });
      return;
    }
    
    if (room.players.length >= 2) {
      socket.emit('gameError', { error: 'Game is full' });
      return;
    }
    
    // Add player to the game
    room.players.push({
      id: socket.id,
      name: playerName || `Player ${socket.id.substring(0, 4)}`,
      selectedNfts,
      ready: false,
      usedStats: []
    });
    
    // Join socket to room channel
    socket.join(gameCode);
    
    // Notify existing player that opponent joined
    socket.to(gameCode).emit('opponentJoined', { 
      opponentName: playerName || `Player ${socket.id.substring(0, 4)}`
    });
    
    // Send game info to joining player
    socket.emit('gameJoined', { 
      gameId: room.id, 
      gameCode,
      opponent: {
        name: room.players[0].name
      }
    });
    
    console.log(`Player joined game: ${gameCode}`);
  });
  
  // Player ready with NFT selection
  socket.on('playerReady', ({ gameCode, selectedNfts }) => {
    const room = gameRooms.get(gameCode);
    if (!room) return;
    
    // Find player and update NFT selection
    const player = room.players.find(p => p.id === socket.id);
    if (player) {
      player.selectedNfts = selectedNfts;
      player.ready = true;
      
      // Check if both players are ready
      const allReady = room.players.length === 2 && room.players.every(p => p.ready);
      if (allReady) {
        room.status = 'playing';
        io.to(gameCode).emit('gameStarted', {
          players: room.players.map(p => ({
            id: p.id,
            name: p.name,
            isCurrentPlayer: false
          })),
          currentRound: 0
        });
      } else {
        // Inform other player this player is ready
        socket.to(gameCode).emit('opponentReady');
      }
    }
  });
  
  // Select stat for current round
  socket.on('selectStat', ({ gameCode, nftId, stat, statValue }) => {
    const room = gameRooms.get(gameCode);
    if (!room) return;
    
    // Find the player
    const playerIndex = room.players.findIndex(p => p.id === socket.id);
    if (playerIndex === -1) return;
    
    const player = room.players[playerIndex];
    const opponent = room.players[playerIndex === 0 ? 1 : 0];
    
    // Record stat selection
    player.currentSelection = { nftId, stat, statValue };
    player.usedStats.push(stat);
    
    // Notify opponent of selection (without revealing the stat)
    socket.to(gameCode).emit('opponentSelected');
    
    // If both players have made selections, calculate round result
    if (player.currentSelection && opponent.currentSelection) {
      const playerValue = parseInt(player.currentSelection.statValue);
      const opponentValue = parseInt(opponent.currentSelection.statValue);
      
      let roundWinner;
      if (playerValue > opponentValue) {
        roundWinner = player.id;
      } else if (opponentValue > playerValue) {
        roundWinner = opponent.id;
      } else {
        roundWinner = 'draw';
      }
      
      // Create round result
      const roundResult = {
        players: [
          {
            id: player.id,
            nftId: player.currentSelection.nftId,
            stat: player.currentSelection.stat,
            statValue: player.currentSelection.statValue
          },
          {
            id: opponent.id,
            nftId: opponent.currentSelection.nftId,
            stat: opponent.currentSelection.stat,
            statValue: opponent.currentSelection.statValue
          }
        ],
        winner: roundWinner
      };
      
      // Add round to game history
      room.rounds.push(roundResult);
      room.currentRound++;
      
      // Reset current selections
      player.currentSelection = null;
      opponent.currentSelection = null;
      
      // Check if game is complete
      if (room.rounds.length >= 3) {
        room.status = 'completed';
        
        // Calculate final result
        const player1Wins = room.rounds.filter(r => r.winner === room.players[0].id).length;
        const player2Wins = room.rounds.filter(r => r.winner === room.players[1].id).length;
        
        let gameWinner;
        if (player1Wins > player2Wins) {
          gameWinner = room.players[0].id;
        } else if (player2Wins > player1Wins) {
          gameWinner = room.players[1].id;
        } else {
          gameWinner = 'draw';
        }
        
        // Send game results to both players
        io.to(gameCode).emit('gameComplete', {
          rounds: room.rounds,
          winner: gameWinner,
          score: `${player1Wins}-${player2Wins}`
        });
      } else {
        // Send round result and advance to next round
        io.to(gameCode).emit('roundComplete', {
          roundResult,
          nextRound: room.currentRound
        });
      }
    }
  });
  
  // Handle player disconnect
  socket.on('disconnect', () => {
    console.log(`Player disconnected: ${socket.id}`);
    
    // Find all games this player is in
    for (const [code, room] of gameRooms.entries()) {
      const playerIndex = room.players.findIndex(p => p.id === socket.id);
      if (playerIndex !== -1) {
        // Notify other player that opponent left
        socket.to(code).emit('opponentLeft');
        
        // Remove the game if it hasn't started
        if (room.status === 'waiting') {
          gameRooms.delete(code);
        }
        break;
      }
    }
  });
});

// Initialize the scheduler to run daily updates
const statsScheduler = initScheduler();

// Optional: Run an initial update when the server starts
// Uncomment the next line if you want to run an update on server start
// statsScheduler.runNow();

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log('Player stats scheduler initialized. Updates will run daily at 2:00 AM.');
});