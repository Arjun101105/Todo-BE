const express = require("express");
const mongoose = require("mongoose");
const { userRouter } = require("./routes/user");
const { todoRouter } = require("./routes/todo");
const { tagRouter } = require("./routes/tag"); // Add this line
const cors = require('cors')

const app = express();
app.use(express.json());
app.use(cors({ origin: 'http://localhost:5173' }));
app.use("/user", userRouter);
app.use("/todo", todoRouter);
app.use("/tag", tagRouter); // Add this line

async function main(){
    await mongoose.connect(process.env.MONGO_URI)
    app.listen(3000)
    console.log(`app listening on port 3000 ...`);   
}

main();