const express = require("express");
const bcrypt = require("bcrypt");
const { UserModel } = require("../db/db");
const jwt = require("jsonwebtoken");
const userRouter = express.Router();
require("dotenv").config();


userRouter.post("/signup", async(req, res)=>{
    const username = req.body.username;
    const email = req.body.email;
    const password = req.body.password;

    const hashedPassword = await bcrypt.hash(password, 10);

    let errorThrown = false;

    try{
        await UserModel.create({
            username: username,
            email: email,
            password: hashedPassword
        })
    }catch(e){
        res.json({
            message: "User already exists"
        })
        errorThrown = true
    }
    if(!errorThrown){
        res.json({
            message: "You are signed up !"
        })
    }
})

userRouter.post("/signin", async(req,res)=>{
    const username = req.body.username;
    const password = req.body.password;

    try {
        // Find the user by username
        const user = await UserModel.findOne({ username: username });

        if(!user) {
            return res.status(403).json({
                message: "Invalid username or password"
            });
        }

        // Compare the input password with the stored hashed password
        const passwordMatch = await bcrypt.compare(password, user.password);

        if(passwordMatch) {
            const token = jwt.sign({
                username: username,
                userId: user._id // Include user ID in token for later use
            }, process.env.JWT_SECRET);

            res.json({
                message: "Login successful",
                token: token
            });
        } else {
            res.status(403).json({
                message: "Invalid username or password"
            });
        }
    } catch(error) {
        console.error(error);
        res.status(500).json({
            message: "An error occurred during sign in"
        });
    }
})

module.exports = { userRouter }