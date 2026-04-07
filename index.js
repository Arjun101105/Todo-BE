const express = require("express");
const mongoose = require("mongoose");
const { userRouter } = require("./routes/user");
const { todoRouter } = require("./routes/todo");
const { tagRouter } = require("./routes/tag"); // Add this line
const cors = require('cors')
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const CORS_ORIGIN = process.env.CORS_ORIGIN || 'http://localhost:5173';

app.use(express.json());
app.use(cors({ origin: CORS_ORIGIN }));
app.use("/user", userRouter);
app.use("/todo", todoRouter);
app.use("/tag", tagRouter); // Add this line

// Health check endpoint for monitoring & load balancers
app.get('/health', (req, res) => {
    res.status(200).json({
        status: 'UP',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: process.env.NODE_ENV || 'development'
    });
});

async function main(){
    await mongoose.connect(process.env.MONGO_URI)
    app.listen(PORT)
    console.log(`app listening on port ${PORT} ...`);   
}

main();