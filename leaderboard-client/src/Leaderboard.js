import React, { useState, useEffect } from 'react';
import axios from 'axios';

const Leaderboard = () => {
  const [leaderboard, setLeaderboard] = useState([]);

  useEffect(() => {
    axios.get('http://localhost:8000/api/leaderboard')
      .then(response => {
        setLeaderboard(response.data);
      })
      .catch(error => {
        console.error("There was an error fetching the leaderboard!", error);
      });
  }, []);

  return (
    <div>
      <h1>Leaderboard App</h1>
      <ul>
        {leaderboard.map((entry, index) => (
          <li key={index}>
            {entry.username} - {entry.score}
          </li>
        ))}
      </ul>
    </div>
  );
};

export default Leaderboard;
