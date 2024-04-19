import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChatScreen());
}

class ChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Screen',
      theme: ThemeData(
        primaryColor: Colors.blue,
      ),
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue, // Starting color
                Colors.lightBlue, // Ending color
              ],
            ),
          ),
          child: ChatScreenPage(),
        ),
      ),
    );
  }
}

class ChatScreenPage extends StatefulWidget {
  @override
  _ChatScreenPageState createState() => _ChatScreenPageState();
}

class _ChatScreenPageState extends State<ChatScreenPage> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText(); // Speech recognition object
  bool _isListening = false;
  String _text = '';

  String selectedLanguage = 'English'; // Default language selection

  Map<String, dynamic> _responses = {}; // Map to store responses

  @override
  void initState() {
    super.initState();
    _loadResponses(); // Load responses when the screen initializes
  }

  // Function to load responses based on selected language
  void _loadResponses() async {
    String language = selectedLanguage.toLowerCase();
    String responsesFilePath = 'assets/responses_${language}.json'; // File path based on language
    try {
      String data = await rootBundle.loadString(responsesFilePath); // Load JSON file from assets
      setState(() {
        _responses = json.decode(data); // Parse JSON data
      });
    } catch (e) {
      print('Error loading responses: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('Chat Screen')),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: Column(
        children: <Widget>[
          Flexible(
            child: ListView.builder(
              reverse: true,
              itemCount: _responses.length,
              itemBuilder: (BuildContext context, int index) {
                var response = _responses.keys.elementAt(index);
                return ListTile(
                  title: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Container(
                        padding: EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          _responses[response],
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: Column(
              children: [
                // Language selection dropdown
                DropdownButton<String>(
                  value: selectedLanguage,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedLanguage = newValue!;
                      _loadResponses(); // Reload responses when language changes
                    });
                  },
                  items: <String>[
                    'English',
                    'Malayalam',
                    'Arabic',
                    // Add more languages here
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                _buildTextComposer(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).primaryColor),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: <Widget>[
            Flexible(
              child: TextField(
                controller: _controller,
                onSubmitted: _handleSubmit,
                decoration: InputDecoration(
                  hintText: "Send a message",
                  contentPadding: EdgeInsets.all(16.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide(color: Colors.blueGrey),
                  ),
                  filled: true,
                  fillColor: Colors.blue[200],
                ),
              ),
            ),
            GestureDetector(
              onTap: _toggleListening,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 4.0),
                child: _isListening
                    ? RecordingAnimation() // Use the custom recording animation
                    : Icon(Icons.mic),
              ),
            ),

            Container(
              margin: EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: Icon(Icons.send),
                onPressed: () {
                  _handleSubmit(_controller.text.trim());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          print('status: $status');
        },
        onError: (error) {
          print('error: $error');
          setState(() => _isListening = false); // Reset listening state on error
        },
      );
      if (available) {
        setState(() => _isListening = true);
        bool started = await _speech.listen(
          onResult: (result) => setState(() {
            _text = result.recognizedWords;
            _controller.text = _text; // Update text field with recognized speech
          }),
        );
        if (!started) {
          setState(() => _isListening = false); // Reset listening state if not started
        }
      } else {
        print('Speech recognition not available');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _handleSubmit(String messageText) async {
    if (messageText.isNotEmpty) {
      _addMessage(messageText); // Add user message
    }
  }

  void _addMessage(String messageText) {
    setState(() {
      _responses[messageText] = _getResponse(messageText); // Add user message and corresponding response
    });
  }

  String? _getResponse(String messageText) {
    return _responses[messageText.toLowerCase()] as String?;
  }
}

class RecordingAnimation extends StatefulWidget {
  @override
  _RecordingAnimationState createState() => _RecordingAnimationState();
}

class _RecordingAnimationState extends State<RecordingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addListener(() {
      setState(() {});
    });
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.0,
      height: 40.0,
      child: CircularProgressIndicator(
        value: _animation.value,
        strokeWidth: 4.0,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
    );
  }
}
