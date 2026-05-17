package com.clicky.demo

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.clicky.sdk.ClickyAssistantHost
import com.clicky.sdk.ClickyConfig
import com.clicky.sdk.ClickyScreen
import com.clicky.sdk.clickyElement
import java.util.UUID

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { /* user choice */ }
            .launch(Manifest.permission.RECORD_AUDIO)

        setContent {
            MaterialTheme {
                // THIS IS THE WHOLE INTEGRATION
                // 1. Wrap your app in ClickyAssistantHost(config = ...)
                // 2. Tag guidable composables with Modifier.clickyElement("id")
                // 3. Call ClickyScreen("ScreenName", state = "...") on screen enter
                ClickyAssistantHost(
                    config = ClickyConfig(
                        anthropicApiKey = "PASTE_YOUR_ANTHROPIC_API_KEY_HERE",
                        appMapJson = AppMap.JSON,
                    ),
                ) {
                    AppNavGraph()
                }
            }
        }
    }
}

// ---------- Model + store ----------

data class Note(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val body: String,
    val hasReminder: Boolean,
)

class NotesStore {
    val notes = mutableStateListOf<Note>()
    fun add(note: Note) { notes.add(0, note) }
    fun delete(noteId: String) { notes.removeAll { it.id == noteId } }
    fun get(noteId: String): Note? = notes.firstOrNull { it.id == noteId }
}

private val LocalNotesStore = staticCompositionLocalOf<NotesStore> {
    error("NotesStore not provided")
}

// ---------- Navigation ----------

@Composable
fun AppNavGraph() {
    val nav = rememberNavController()
    val notesStore = remember { NotesStore() }

    CompositionLocalProvider(LocalNotesStore provides notesStore) {
        NavHost(navController = nav, startDestination = "list") {
            composable("list") { NotesListScreen(nav) }
            composable("create") { CreateNoteScreen(nav) }
            composable("detail/{noteId}") { backStack ->
                val noteId = backStack.arguments?.getString("noteId") ?: return@composable
                NoteDetailScreen(nav, noteId)
            }
        }
    }
}

// ---------- Screens ----------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotesListScreen(nav: NavHostController) {
    val notesStore = LocalNotesStore.current
    val state = "Number of notes: ${notesStore.notes.size}. ${if (notesStore.notes.isEmpty()) "List is empty." else ""}"
    ClickyScreen(id = "NotesListScreen", state = state)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Notes") },
                actions = {
                    IconButton(
                        onClick = { nav.navigate("create") },
                        modifier = Modifier.clickyElement("new-note-button"),
                    ) {
                        Icon(Icons.Filled.Add, contentDescription = "New note")
                    }
                },
            )
        },
    ) { padding ->
        if (notesStore.notes.isEmpty()) {
            Column(
                modifier = Modifier.fillMaxSize().padding(padding),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text("No notes yet", style = MaterialTheme.typography.titleMedium)
                Text("Tap + in the top right to create one", color = Color.Gray)
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .clickyElement("notes-list"),
            ) {
                items(notesStore.notes, key = { it.id }) { note ->
                    ListItem(
                        headlineContent = { Text(note.title, fontWeight = FontWeight.SemiBold) },
                        supportingContent = { if (note.body.isNotEmpty()) Text(note.body, maxLines = 2) },
                        trailingContent = {
                            if (note.hasReminder) {
                                Icon(Icons.Filled.Notifications, contentDescription = "Reminder", tint = Color(0xFFFF9500))
                            }
                        },
                        modifier = Modifier.clickable { nav.navigate("detail/${note.id}") },
                    )
                    HorizontalDivider()
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateNoteScreen(nav: NavHostController) {
    val notesStore = LocalNotesStore.current
    var titleText by rememberSaveable { mutableStateOf("") }
    var bodyText by rememberSaveable { mutableStateOf("") }
    var hasReminder by rememberSaveable { mutableStateOf(false) }

    val screenState = "Title: ${if (titleText.isEmpty()) "(empty)" else "\"$titleText\""}, body length: ${bodyText.length}, reminder: ${if (hasReminder) "on" else "off"}, save enabled: ${titleText.isNotBlank()}"
    ClickyScreen(id = "CreateNoteScreen", state = screenState)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("New Note") },
                navigationIcon = {
                    TextButton(onClick = { nav.popBackStack() }, modifier = Modifier.clickyElement("cancel-button")) {
                        Text("Cancel")
                    }
                },
                actions = {
                    TextButton(
                        enabled = titleText.isNotBlank(),
                        onClick = {
                            notesStore.add(Note(title = titleText, body = bodyText, hasReminder = hasReminder))
                            nav.popBackStack()
                        },
                        modifier = Modifier.clickyElement("save-button"),
                    ) { Text("Save") }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            OutlinedTextField(
                value = titleText,
                onValueChange = { titleText = it },
                label = { Text("Title") },
                modifier = Modifier.fillMaxWidth().clickyElement("title-field"),
            )
            OutlinedTextField(
                value = bodyText,
                onValueChange = { bodyText = it },
                label = { Text("Body") },
                modifier = Modifier.fillMaxWidth().height(160.dp).clickyElement("body-field"),
            )
            Row(
                modifier = Modifier.fillMaxWidth().clickyElement("reminder-toggle"),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Reminder", modifier = Modifier.weight(1f))
                Switch(checked = hasReminder, onCheckedChange = { hasReminder = it })
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteDetailScreen(nav: NavHostController, noteId: String) {
    val notesStore = LocalNotesStore.current
    val note = notesStore.get(noteId) ?: return
    ClickyScreen(id = "NoteDetailScreen", state = "Viewing \"${note.title}\", reminder: ${if (note.hasReminder) "on" else "off"}")

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Note") },
                actions = {
                    IconButton(
                        onClick = { notesStore.delete(noteId); nav.popBackStack() },
                        modifier = Modifier.clickyElement("delete-button"),
                    ) {
                        Icon(Icons.Filled.Delete, contentDescription = "Delete", tint = Color(0xFFFF453A))
                    }
                },
            )
        },
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(note.title, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.width(8.dp))
                if (note.hasReminder) Icon(Icons.Filled.Notifications, contentDescription = null, tint = Color(0xFFFF9500))
            }
            Spacer(Modifier.height(16.dp))
            Text(note.body)
        }
    }
}
