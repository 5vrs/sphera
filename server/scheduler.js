const schedule = require('node-schedule');
const { spawn } = require('child_process');
const path = require('path');

// Configure paths
const pythonScriptPath = path.join(__dirname, '../src/playerstats/updatestats.py');

// Function to run the Python script
function runPlayerStatsUpdate() {
  console.log('Running scheduled player stats update...');
  
  // Use spawn to run the Python script
  const pythonProcess = spawn('python3', [pythonScriptPath]);
  
  pythonProcess.stdout.on('data', (data) => {
    console.log(`Player Stats Update: ${data}`);
  });
  
  pythonProcess.stderr.on('data', (data) => {
    console.error(`Player Stats Update Error: ${data}`);
  });
  
  pythonProcess.on('close', (code) => {
    console.log(`Player Stats Update completed with code ${code}`);
  });
}

// Schedule the job to run daily at 2:00 AM
function initScheduler() {
  console.log('Initializing player stats update scheduler...');
  
  // Run at 2:00 AM every day
  const job = schedule.scheduleJob('0 2 * * *', runPlayerStatsUpdate);
  
  // Also provide a way to run it manually if needed
  return {
    runNow: runPlayerStatsUpdate,
    job
  };
}

module.exports = { initScheduler };