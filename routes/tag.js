const express = require("express");
const { TagModel, TodoModel } = require("../db/db");
const { authenticateToken } = require("../middleware/auth");

const tagRouter = express.Router();

// Get all tags for the current user
tagRouter.get("/", authenticateToken, async (req, res) => {
  try {
    const tags = await TagModel.find({ userId: req.user.userId });
    res.json({
      message: "Tags retrieved successfully",
      tags: tags
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch tags",
      error: error.message
    });
  }
});

// Create a new tag
tagRouter.post("/", authenticateToken, async (req, res) => {
  try {
    const { name, color } = req.body;
    
    // Check if tag already exists for this user
    const existingTag = await TagModel.findOne({ 
      name: name, 
      userId: req.user.userId 
    });
    
    if (existingTag) {
      return res.status(400).json({
        message: "A tag with this name already exists",
        tag: existingTag
      });
    }
    
    // Create new tag
    const newTag = await TagModel.create({
      name,
      color: color || "#cccccc",
      userId: req.user.userId
    });
    
    res.status(201).json({
      message: "Tag created successfully",
      tag: newTag
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to create tag",
      error: error.message
    });
  }
});

// Update an existing tag
tagRouter.put("/:id", authenticateToken, async (req, res) => {
  const tagId = req.params.id;
  const userId = req.user.userId;
  const { name, color } = req.body;
  
  try {
    // First verify the tag belongs to the authenticated user
    const existingTag = await TagModel.findOne({
      _id: tagId,
      userId
    });
    
    if (!existingTag) {
      return res.status(404).json({
        message: "Tag not found or you don't have permission to update it"
      });
    }
    
    // Check if the new name already exists (if name is being updated)
    if (name && name !== existingTag.name) {
      const duplicateTag = await TagModel.findOne({
        name,
        userId,
        _id: { $ne: tagId } // Exclude the current tag
      });
      
      if (duplicateTag) {
        return res.status(400).json({
          message: "A tag with this name already exists",
          tag: duplicateTag
        });
      }
    }
    
    // Prepare update object
    const updateData = {};
    if (name) updateData.name = name;
    if (color) updateData.color = color;
    
    // Update the tag
    const updatedTag = await TagModel.findByIdAndUpdate(
      tagId,
      updateData,
      { new: true } // Return the updated document
    );
    
    res.json({
      message: "Tag updated successfully",
      tag: updatedTag
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to update tag",
      error: error.message
    });
  }
});

// Delete a tag and handle associated todos
tagRouter.delete("/:id", authenticateToken, async (req, res) => {
  const tagId = req.params.id;
  const userId = req.user.userId;
  
  try {
    // First verify the tag belongs to the authenticated user
    const existingTag = await TagModel.findOne({
      _id: tagId,
      userId
    });
    
    if (!existingTag) {
      return res.status(404).json({
        message: "Tag not found or you don't have permission to delete it"
      });
    }
    
    // Option 1: Remove tag references from todos (set to null)
    await TodoModel.updateMany(
      { tagId: tagId },
      { $set: { tagId: null } }
    );
    
    // Delete the tag
    await TagModel.findByIdAndDelete(tagId);
    
    res.json({
      message: "Tag deleted successfully and removed from associated todos"
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to delete tag",
      error: error.message
    });
  }
});

// Get todos by tag
tagRouter.get("/:id/todos", authenticateToken, async (req, res) => {
  const tagId = req.params.id;
  const userId = req.user.userId;
  
  try {
    // First verify the tag belongs to the authenticated user
    const tag = await TagModel.findOne({
      _id: tagId,
      userId
    });
    
    if (!tag) {
      return res.status(404).json({
        message: "Tag not found or you don't have permission to access it"
      });
    }
    
    // Find todos with this tag
    const todos = await TodoModel.find({
      tagId: tagId,
      userId: userId
    });
    
    res.json({
      message: `Found ${todos.length} todos with this tag`,
      tag: tag,
      todos: todos
    });
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch todos by tag",
      error: error.message
    });
  }
});

module.exports = { tagRouter };