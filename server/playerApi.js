const express = require('express');
const fs = require('fs');
const csv = require('csv-parser');
const { createObjectCsvWriter } = require('csv-writer');
const path = require('path');
const axios = require('axios'); // We need to add axios for HTTP requests
const router = express.Router();

// Function to fetch NFT metadata from IPFS
async function fetchNFTMetadata(nftId) {
  try {
    // The base IPFS URL from the contract
    const baseIpfsUrl = "ipfs://bafybeihlluxsxvi2le6kh5josgvsxtynbvwjszbgmy5wgqoxfauymrv6ni";
    
    // Convert IPFS URL to HTTP URL using a public gateway
    const gatewayUrl = baseIpfsUrl.replace('ipfs://', 'https://ipfs.io/ipfs/');
    
    // Fetch the metadata
    const response = await axios.get(`${gatewayUrl}/${nftId}.json`);
    return response.data;
  } catch (error) {
    console.error('Error fetching NFT metadata:', error);
    // If we can't fetch from IPFS, try local file as fallback
    try {
      const localPath = path.resolve(__dirname, `../nfts/json/${nftId}.json`);
      const data = fs.readFileSync(localPath, 'utf8');
      return JSON.parse(data);
    } catch (localError) {
      console.error('Error reading local JSON file:', localError);
      throw new Error('Failed to fetch NFT metadata');
    }
  }
}

// API endpoint to assign an NFT to a random player
router.post('/assign-nft-to-player', async (req, res) => {
  const { nftId } = req.body;
  
  if (!nftId) {
    return res.status(400).json({ error: 'NFT ID is required' });
  }
  
  const csvPath = path.resolve(__dirname, '../src/playerstats/players.csv');
  const players = [];
  
  try {
    // First, fetch the NFT metadata to get the addition value
    const metadata = await fetchNFTMetadata(nftId);
    const additionValue = metadata.addition || 0;
    
    console.log(`NFT #${nftId} has addition value: ${additionValue}`);
    
    // Read and parse the CSV file
    await new Promise((resolve, reject) => {
      fs.createReadStream(csvPath)
        .pipe(csv())
        .on('data', (row) => players.push(row))
        .on('end', resolve)
        .on('error', reject);
    });
    
    // Find players with NFTID = 0
    const availablePlayers = players.filter(player => player.NFTID === '0');
    
    if (availablePlayers.length === 0) {
      return res.status(404).json({ error: 'No available players found' });
    }
    
    // Select a random player
    const randomIndex = Math.floor(Math.random() * availablePlayers.length);
    const selectedPlayer = availablePlayers[randomIndex];
    
    // Find the player's index in the original array
    const playerIndex = players.findIndex(p => 
      p.Name === selectedPlayer.Name && 
      p.ID === selectedPlayer.ID && 
      p.Team === selectedPlayer.Team
    );
    
    // Update the player's NFTID and stats with the addition value
    players[playerIndex].NFTID = nftId.toString();
    
    // Add the addition value to each stat
    players[playerIndex].Attacking = (parseInt(players[playerIndex].Attacking) + additionValue).toString();
    players[playerIndex].Midfielding = (parseInt(players[playerIndex].Midfielding) + additionValue).toString();
    players[playerIndex].Defending = (parseInt(players[playerIndex].Defending) + additionValue).toString();
    
    // Write the updated data back to CSV
    const csvWriter = createObjectCsvWriter({
      path: csvPath,
      header: [
        { id: 'Name', title: 'Name' },
        { id: 'Position', title: 'Position' },
        { id: 'Team', title: 'Team' },
        { id: 'ID', title: 'ID' },
        { id: 'NFTID', title: 'NFTID' },
        { id: 'Attacking', title: 'Attacking' },
        { id: 'Midfielding', title: 'Midfielding' },
        { id: 'Defending', title: 'Defending' }
      ]
    });
    
    await csvWriter.writeRecords(players);
    
    // Return the assigned player with updated stats
    return res.status(200).json({
      success: true,
      player: players[playerIndex],
      additionApplied: additionValue
    });
    
  } catch (err) {
    console.error('Error processing request:', err);
    return res.status(500).json({ error: 'Failed to process request: ' + err.message });
  }
});

// Get players by NFT IDs
router.get('/get-players-by-nft-ids', async (req, res) => {
  try {
    const nftIdsStr = req.query.nftIds;
    if (!nftIdsStr) {
      return res.status(400).json({ error: 'NFT IDs are required' });
    }
    
    // Convert all IDs to strings for consistent comparison
    const nftIds = nftIdsStr.split(',').map(id => id.toString().trim());
    const csvPath = path.resolve(__dirname, '../src/playerstats/players.csv');
    const players = [];
    
    // Read and parse the CSV file
    await new Promise((resolve, reject) => {
      fs.createReadStream(csvPath)
        .pipe(csv())
        .on('data', (row) => {
          // Convert NFTID to string for consistent comparison
          if (nftIds.includes(row.NFTID.toString())) {
            players.push(row);
          }
        })
        .on('end', resolve)
        .on('error', reject);
    });
    
    return res.status(200).json(players);
  } catch (err) {
    console.error('Error processing request:', err);
    return res.status(500).json({ error: 'Failed to process request' });
  }
});

module.exports = router;