const express = require("express");
const { TodoModel, TagModel } = require("../db/db");
const { authenticateToken } = require("../middleware/auth");

const todoRouter = express.Router();

todoRouter.post("/add-todo", authenticateToken, async (req, res) => {
  const title = req.body.title;
  const description = req.body.description;
  const dueDate = req.body.dueDate;
  const tagInput = req.body.tagId; // Changed from req.body.tag
  const completed = req.body.completed || false;
  const userId = req.user.userId;

  try {
    let tagId = null; // Allow todos without tags
    if (tagInput) {
      if (tagInput.match(/^[0-9a-fA-F]{24}$/)) {
        const existingTag = await TagModel.findOne({ _id: tagInput, userId });
        if (existingTag) {
          tagId = existingTag._id;
        } else {
          return res.status(400).json({ message: "Invalid tag ID" });
        }
      } else {
        const newTag = await TagModel.create({ name: tagInput, userId });
        tagId = newTag._id;
      }
    }
    const newTodo = await TodoModel.create({ title, description, dueDate, tagId, userId, completed });
    const populatedTodo = await TodoModel.findById(newTodo._id).populate('tagId').exec();
    res.status(201).json({ message: "Todo created successfully", todo: populatedTodo });
  } catch (error) {
    console.error('Create Todo Error:', error);
    res.status(500).json({ message: "Failed to create todo", error: error.message });
  }
});

//get todo
todoRouter.get("/", authenticateToken, async(req, res) => {
    const userId = req.user.userId;
    const { tag, completed, sort, limit = 10, page = 1 } = req.query;
    
    // Build query filters
    const filter = { userId };
    
    // Filter by tag if provided
    if (tag) {
        // Find tag by name or ID
        let tagObj;
        if (tag.match(/^[0-9a-fA-F]{24}$/)) {
            tagObj = await TagModel.findOne({ _id: tag, userId });
        } else {
            tagObj = await TagModel.findOne({ name: tag, userId });
        }
        
        if (tagObj) {
            filter.tagId = tagObj._id;
        }
    }
    
    // Filter by completion status if provided
    if (completed !== undefined) {
        filter.completed = completed === 'true';
    }
    
    try {
        // Create sort configuration
        const sortConfig = {};
        if (sort === 'dueDate') sortConfig.dueDate = 1;
        else if (sort === '-dueDate') sortConfig.dueDate = -1;
        else if (sort === 'title') sortConfig.title = 1;
        else if (sort === '-title') sortConfig.title = -1;
        else sortConfig.createdAt = -1; // Default: newest first
        
        // Calculate pagination
        const skip = (page - 1) * limit;
        
        // Execute query with filters, sorting, and pagination
        const todos = await TodoModel.find(filter)
            .populate('tagId')
            .sort(sortConfig)
            .skip(skip)
            .limit(parseInt(limit))
            .exec();
            
        // Get total count for pagination info
        const totalCount = await TodoModel.countDocuments(filter);
        
        res.json({
            message: "Todos retrieved successfully",
            count: todos.length,
            total: totalCount,
            page: parseInt(page),
            totalPages: Math.ceil(totalCount / limit),
            todos: todos
        });
    } catch (error) {
        res.status(500).json({
            message: "Failed to retrieve todos",
            error: error.message
        });
    }
});
// Update an existing todo
todoRouter.put("/:id", authenticateToken, async(req, res) => {
    const todoId = req.params.id;
    const userId = req.user.userId;
    const { title, description, dueDate, completed, tag } = req.body;
    
    try {
        // First verify this todo belongs to the authenticated user
        const existingTodo = await TodoModel.findOne({ 
            _id: todoId, 
            userId 
        });
        
        if (!existingTodo) {
            return res.status(404).json({
                message: "Todo not found or you don't have permission to update it"
            });
        }
        
        // Prepare update object with provided fields
        const updateData = {};
        if (title !== undefined) updateData.title = title;
        if (description !== undefined) updateData.description = description;
        if (dueDate !== undefined) updateData.dueDate = dueDate;
        if (completed !== undefined) updateData.completed = completed;
        
        // Handle tag update if provided
        if (tag !== undefined) {
            let tagId;
            
            // Check if tag is an ObjectId (existing tag)
            if (tag.match(/^[0-9a-fA-F]{24}$/)) {
                const existingTag = await TagModel.findOne({ 
                    _id: tag,
                    userId
                });
                
                if (existingTag) {
                    tagId = existingTag._id;
                }
            }
            
            // If tag isn't an existing one, create a new tag
            if (!tagId) {
                const newTag = await TagModel.create({
                    name: tag,
                    userId
                });
                tagId = newTag._id;
            }
            
            updateData.tagId = tagId;
        }
        
        // Update the todo and return the updated version
        const updatedTodo = await TodoModel.findByIdAndUpdate(
            todoId, 
            updateData, 
            { new: true } // Return the updated document
        ).populate('tagId');
        
        res.json({
            message: "Todo updated successfully",
            todo: updatedTodo
        });
    } catch (error) {
        res.status(500).json({
            message: "Failed to update todo",
            error: error.message
        });
    }
});

// Delete a todo
todoRouter.delete("/:id", authenticateToken, async(req, res) => {
    const todoId = req.params.id;
    const userId = req.user.userId;
    
    try {
        // Find and delete the todo, ensuring it belongs to the current user
        const deletedTodo = await TodoModel.findOneAndDelete({ 
            _id: todoId, 
            userId 
        });
        
        if (!deletedTodo) {
            return res.status(404).json({
                message: "Todo not found or you don't have permission to delete it"
            });
        }
        
        res.json({
            message: "Todo deleted successfully",
            todo: deletedTodo
        });
    } catch (error) {
        res.status(500).json({
            message: "Failed to delete todo",
            error: error.message
        });
    }
});

// Toggle todo completion status
todoRouter.patch("/:id/toggle-complete", authenticateToken, async(req, res) => {
    const todoId = req.params.id;
    const userId = req.user.userId;
    
    try {
        // Find the todo, ensuring it belongs to the current user
        const todo = await TodoModel.findOne({ 
            _id: todoId, 
            userId 
        });
        
        if (!todo) {
            return res.status(404).json({
                message: "Todo not found or you don't have permission to update it"
            });
        }
        
        // Toggle the completed status
        todo.completed = !todo.completed;
        await todo.save();
        
        // Populate tag information in the response
        const populatedTodo = await todo.populate('tagId');
        
        res.json({
            message: `Todo marked as ${populatedTodo.completed ? 'completed' : 'pending'}`,
            todo: populatedTodo
        });
    } catch (error) {
        res.status(500).json({
            message: "Failed to update todo completion status",
            error: error.message
        });
    }
});

// Add this for batch operations

// Batch delete completed todos
todoRouter.delete("/batch/completed", authenticateToken, async(req, res) => {
    const userId = req.user.userId;
    
    try {
        const result = await TodoModel.deleteMany({ 
            userId, 
            completed: true 
        });
        
        res.json({
            message: `${result.deletedCount} completed todos were deleted`,
            deletedCount: result.deletedCount
        });
    } catch (error) {
        res.status(500).json({
            message: "Failed to delete completed todos",
            error: error.message
        });
    }
});

// Add a route to get todo statistics
todoRouter.get("/stats", authenticateToken, async(req, res) => {
    const userId = req.user.userId;
    
    try {
        const totalCount = await TodoModel.countDocuments({ userId });
        const completedCount = await TodoModel.countDocuments({ userId, completed: true });
        const pendingCount = totalCount - completedCount;
        
        // Get count by tag
        const tagStats = await TodoModel.aggregate([
            { $match: { userId: mongoose.Types.ObjectId(userId) } },
            { $group: {
                _id: "$tagId",
                total: { $sum: 1 },
                completed: { $sum: { $cond: ["$completed", 1, 0] } },
                pending: { $sum: { $cond: ["$completed", 0, 1] } }
            }}
        ]);
        
        // Populate tag information
        const populatedTagStats = await TagModel.populate(tagStats, {
            path: "_id",
            select: "name color"
        });
        
        res.json({
            total: totalCount,
            completed: completedCount,
            pending: pendingCount,
            completionRate: totalCount > 0 ? (completedCount / totalCount) * 100 : 0,
            tagStats: populatedTagStats
        });
    } catch (error) {
        res.status(500).json({
            message: "Failed to retrieve todo statistics",
            error: error.message
        });
    }
});

// Add a specific route to get todos by completion status
todoRouter.get("/status/:completed", authenticateToken, async(req, res) => {
    const userId = req.user.userId;
    const isCompleted = req.params.completed === 'completed';
    
    try {
        const todos = await TodoModel.find({
            userId,
            completed: isCompleted
        })
        .populate('tagId')
        .sort({ updatedAt: -1 })
        .exec();
        
        res.json({
            message: `Retrieved ${isCompleted ? 'completed' : 'pending'} todos`,
            count: todos.length,
            todos: todos
        });
    } catch (error) {
        res.status(500).json({
            message: "Failed to retrieve todos",
            error: error.message
        });
    }
});


module.exports = { todoRouter };

