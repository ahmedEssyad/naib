package com.clicky.demo

object AppMap {
    const val JSON = """
{
  "appName": "ClickyDemo Notes",
  "description": "A simple notes app. Users can list, create, view, and delete notes. Each note has a title, body, and optional reminder toggle.",
  "screens": [
    {
      "id": "NotesListScreen",
      "title": "Notes List",
      "elements": [
        { "id": "new-note-button", "label": "New note (+) button", "description": "Opens the create-note screen." },
        { "id": "notes-list", "label": "List of existing notes" }
      ]
    },
    {
      "id": "CreateNoteScreen",
      "title": "Create Note",
      "elements": [
        { "id": "title-field", "label": "Title text field" },
        { "id": "body-field", "label": "Body text field" },
        { "id": "reminder-toggle", "label": "Reminder toggle switch" },
        { "id": "save-button", "label": "Save button" },
        { "id": "cancel-button", "label": "Cancel button" }
      ]
    },
    {
      "id": "NoteDetailScreen",
      "title": "Note Detail",
      "elements": [
        { "id": "delete-button", "label": "Delete note button" }
      ]
    }
  ]
}
"""
}
