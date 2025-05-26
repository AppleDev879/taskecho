class OpenAIResponse {
  final String title;
  final String description;
  final String dateTime;
  final String priority; // "low", "medium", or "high"
  final String category;

  OpenAIResponse({required this.title, required this.description, required this.dateTime, required this.priority, required this.category});

  factory OpenAIResponse.fromJson(Map<String, dynamic> json) {
    return OpenAIResponse(
      title: json['title'] as String,
      description: json['description'] as String,
      dateTime: json['due_date'] as String,
      priority: json['priority'] as String,
      category: json['category'] as String,
    );
  }
}
