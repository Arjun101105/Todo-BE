const mongoose = require("mongoose");
require("dotenv").config();

const PORT = process.env.PORT || 5000;

mongoose.connect(process.env.MONGO_URI)
.then(()=>{
    console.log("mongodb connected")
})
.catch(err => console.err("mongodb connection error: ", err))


const User = new mongoose.Schema({
    username: {type: String, unique: true},
    email: {type: String, unique: true},
    password: String,
    createdAt: {type: Date, default: Date.now}
})

const todoSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: { type: String },
  dueDate: { type: Date },
  tagId: { type: mongoose.Schema.Types.ObjectId, ref: 'Tag' },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  completed: { type: Boolean, default: false } // Add this if not already present
}, { timestamps: true });


// Tag schema
const tagSchema = new mongoose.Schema({
  name: { type: String, required: true },
  color: { type: String, default: "#cccccc" },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true } // User-specific tags
});

// Make sure each user can only have one tag with the same name
tagSchema.index({ name: 1, userId: 1 }, { unique: true });

const UserModel = mongoose.model('users', User);
const TodoModel = mongoose.model("Todo", todoSchema);
const TagModel = mongoose.model("Tag", tagSchema);

module.exports = {
    UserModel: UserModel,
    TodoModel: TodoModel,
    TagModel
}

