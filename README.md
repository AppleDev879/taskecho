# ✅ TaskEcho – A Mobile, AI-Powered, Todo List App

A modern, voice-enabled mobile To Do List app built with Flutter. Add tasks manually or speak them aloud and let AI turn them into structured to-dos. Powered by ISAR for fast local storage and includes local notifications on iOS.

---

## 📱 Features

- **Create To-Dos**  
  Add tasks with:
  - Title
  - Optional description
  - Optional due date
  - Category (`personal`, `worker`, etc.)

- **Categorized Viewing**  
  Tasks with due dates are sortable by category.

- **Voice Input with AI**  
  - Tap the mic to speak tasks naturally.
  - Speech is sent to a custom backend that returns structured task details.
  - Adds structured to-dos automatically.

- **iOS Notifications**  
  Local reminders fire for tasks with due dates.

- **Offline First**  
  Uses [ISAR](https://isar.dev/) for fast local storage. No network required for core features.

- **Empty States**  
  Friendly empty state messages are shown when there are no in-progress or completed tasks.

- **Completed Tasks History**  
  View a full list of all your completed to-dos in a dedicated "Past Completed" tab.

---

## 🧠 Heads Up About Voice Input

🔐 **You'll need a custom API key for my backend (not an OpenAI key) for transcription to work.**  
If you're interested in trying that feature and don’t have the key, just ask me and I’ll get you set up!

---

## 🗂 Project Structure

```
lib/
├── models/
│   ├── openai_response.dart       # Model for backend response format
│   ├── todo.dart                  # Task model
│   └── todo.g.dart                # ISAR-generated code
│
├── providers/
│   ├── filter_provider.dart       # Filter logic for category/date
│   ├── isar_provider.dart         # ISAR instance and CRUD
│   ├── openai_provider.dart       # Transcription + task generation logic
│   ├── tab_provider.dart          # Bottom tab state management
│   └── todo_provider.dart         # Core task logic
│
├── screens/
│   ├── detail_screen.dart         # Task add/edit/detail view
│   └── main_screen.dart           # Entry point, task list + mic
│
├── services/
│   └── local_notifications.dart   # iOS local notifications
│
├── widgets/
│   ├── recording_sheet.dart       # Mic input UI
│   └── todo_list_view.dart        # Task list renderer
│
└── main.dart                      # App entry
```

---

## 🛠 Getting Started

### 1. Clone the Project
```bash
git clone https://github.com/your-username/mobile-todo-app.git
cd mobile-todo-app
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Add Your Custom API Key
In `openai_provider.dart`, set your custom backend key:
```dart
const apiKey = 'your-api-key-here';
```
(You can optionally load this from an `.env` file.)

### 4. Run on a Mobile Device
```bash
flutter run
```

> iOS only: Be sure to enable microphone and notification permissions in Xcode project settings.

---

## 🛣️ Roadmap

- [ ] Add Android local notification support  
- [ ] Export tasks to calendar  
- [ ] Add recurring reminders  
- [ ] Natural language parsing for typed input  
- [ ] Custom themes  

---

## 👤 Author

Made with 🎧 and ☕️ by Andrew Barrett
Questions or feedback? Reach out!

---

## 📄 License

MIT License
