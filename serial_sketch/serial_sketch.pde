/*
 * Simple Arduino proxy; does what it's told
 * via the USB connection, and reports back
 * the values of its inputs. Allows code on
 * the other end of the USB cable to do the
 * computation, so the Arduino is just an IO
 * device rather than a microcontroller.
 */

void setup()
{
  delay(1000);    // Keep this here so we don't lose serial access
  // Set up Serial library at 9600 bps
  Serial.begin(9600);
}

void loop()
{
  Serial.println("Starting...");
  // Look for some commands in JSON
  char* input = 0;
  input = read_json();

  // See what we received...
  if (input==0) {
//    Serial.println("Unknown input");
  }
  else {
    int length = json_length(input);
//    Serial.print("Found ");
//    Serial.print(length);
//    Serial.println(" chars of JSON");
    for (int i=0; i < length; i++) {
//      Serial.print(input[i]);
    }
//    Serial.println("");
  }
}

char read_char()
{
  // Wait until some data becomes available
  // on the USB cable (this will loop
  // forever if you don't send it anything)
  char data = -1;
  while ((Serial.available() < 0) || (data < 0)) {
    delay(25);
    data = Serial.read();
  }
  return data;
}

char* read_json()
{
  // This will wait for some input, then
  // read it to make sure it is an open
  // brace "{" (discarding it if not) and
  // reading all of the input up to a
  // corresponding close brace "}".
  // Nested sets of braces are allowed.
  // Returns a pointer to whatever it's
  // read.
  
  // Wait for some serial input and grab it
  char this_value;
  this_value = read_char();
  
  // See if we should continue reading
  while (this_value != '{')
  {
    // Uh oh, this isn't JSON
//    Serial.println("Unknown input. Please send me JSON");
    // Try again...
    this_value = read_char();
  }
  int nested_count = 1;    // Keep track of how deeply nested our braces are
  int pointer_size = 2;      // The size of our char pointer (must be >= 2, for '{' and '}')
  int read_so_far = 1;     // How much data we've read (used to ensure our pointer is big enough)
  char* result = (char*) malloc(sizeof(char)*pointer_size);    // This pointer will be our return value
  char* new_result;    // Used during pointer reallocation
  result[0] = this_value;    // Set the first value to the '{' that we found
  
  // There are a few exceptions to the simple braced structure...
  short in_quote = 0;
  short in_escape = 0;
  
  while (nested_count > 0)    // Loop until we've closed that first brace
  {
//    Serial.print("Nested to ");
//    Serial.println(nested_count);
    // Wait for input then read it
    this_value = read_char();
    
    // See if we've got enough room to store it
    read_so_far++;
    if (read_so_far > pointer_size)
    {
      // Try to increase the size of our instruction pointer
      char* new_result = (char*) realloc(result, (pointer_size+1));
      if (new_result)
      {
        // We succeeded in allocating enough memory. Let's use it.
        result = new_result;
        pointer_size++;
      }
      else
      {
        // Out of memory. Abort.
        free(result);
        return 0;
      }
    }
    // Store it
    result[read_so_far-1] = this_value;
    
    // Handle this character
    if (in_quote) {
      // String semantics: read in everything up to a non-escaped '"'
      if (in_escape) {
        in_escape = 0;
      }
      else {
        if (this_value == '"') {
          in_quote = 0;
        }
        if (this_value == '\\') {
          in_escape = 1;
        }
      }
    }
    else {
      // Object semantics: Read in everything up to a non-matched '}'
      
      // Recurse down a level
      if (this_value == '{') {
        nested_count++;
      }
      else {
        // Come back up a level
        if (this_value == '}') {
          nested_count--;
        }
        else {
          // Start a string
          if (this_value == '"') {
            in_quote = 1;
          }
          else {
            // Some other character
          }
        }
      }
    }
  }
  return result;
}

int json_length(char* json) {
  // Give this a pointer to some JSON data and it will
  // return the length of that JSON.
  
  if (json == 0) {
    return 0;    // Null pointer
  }
  
  if (json[0] != '{') {
    return 0;    // Not JSON
  }

  // Now that we know we have a JSON object, we defer
  // the actual calculation to value_length
  return value_length(json);
}

int value_length(char* json) {
  // This is given a fragment of JSON and returns how
  // many characters it contains. This fragment might
  // be an object, a number, a string , etc.
  if (json == 0) {
    return 0;    // Null pointer
  }
  
  // Switch over each possibility
  int index = 0;
  switch (json[index]) {
    case '{':
        // This is a JSON object. Find the matching '}'
        do {
          index++;
          if (json[index] == '"') {
            // Skip strings, as they may contain unwanted '}'
            index = index + value_length(json+index);
          }
          if (json[index] == '{') {
            // Recurse past nested objects
            index = index + value_length(json+index);
          }
        } while (json[index] != '}');
        return index + 1;    // Include the '{' and '}' in the length
    case '"':
      // This is a string. Scan ahead to the first unescaped '"'
      do {
        if (json[index] == '\\') {
          index++; // Skip escaped quotes
        }
        index++;    // Read ahead
      } while (json[index] != '"');
      return index+1;    // We include the quotes in the string's length
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
    case '-':
      // We're a number. Loop forever until we find a non-number character.
      // Note, this allows malformed numbers like 0.0.0.0e0.0e.0
      do {
        index++;
        switch (json[index]) {
          case '0':
          case '1':
          case '2':
          case '3':
          case '4':
          case '5':
          case '6':
          case '7':
          case '8':
          case '9':
          case '.':
          case 'e':
          case 'E':
            break;    // Numeric
          default:
            return index;    // Non-numeric. Stop counting.
        }
      } while (1);
  }
}

void read_commands(char* json) {
  // Takes a JSON string and looks for any commands it
  // contains. These are "key":value pairs, which are
  // sent as arguments to the "run_command" function as
  // they are encountered.
  int length = json_length(json);
  int index = 0;    // Used to loop through the contents
  int temp;    // Our parsing uses lookahead, this stores how far we've gone
  
  // Only bother doing something if json has some contents.
  // When this condition is false, it's essentially the
  // escape clause of our recursion.
  if (length > 2) {    // 2 == empty, since we have '{' and '}'
    index++;    // Skip past the '{' to get at the contents
    while (index < length) {
      switch (json[index]) {
        case ' ':
          // Whitespace is insignificant
          index++;
          break;
        case '{':
          // We have an object in an object, let's recurse
          read_commands(json+index);
          index = index + json_length(json+index);
          break;
        case '"':
          // A string. This should be part of a key:value pair
          if (index + 2 >= length) {
            // JSON can't end with an opening quote. Bail out.
            break;
          }
          
          // Look one character ahead, then keep going until
          // we find our matching close quote
          temp = index+1;
          while ((json[temp] != '"') && (temp < length)) {
            // We've not found our close quote, so look ahead
            if (json[temp] == '\\') {
              // Increment twice to skip over escaped characters
              temp++;
            }
            temp++;
          }
          if (temp >= length-2) {
            // We've reached the end of the JSON without finding
            // a close quote. Bail out.
            break;
          }
          
          // Now we've read our name, find our associated value
          temp++;    // It must start after the close quote
          while ((json[temp] == ' ') && (temp < length)) {
            temp++;    // Skip whitespace
          }
          if (json[temp] != ':') {
            // We must have a colon between the name and the value
            // Bail out if not
            break;
          }
          temp++;    // We don't need the colon, skip it
          while ((json[temp] == ' ') && (temp < length)) {
            temp++;    // Skip whitespace
          }
          
          // Wherever we are, we must have found our value
          // Tell run_command what we've found
          run_command(json+index, json+temp);
          
          // Now let's get our parser ready for the next value
          index = temp + value_length(json+temp);    // Skip the value
          while ((json[index] == ' ') && (index < length)) {
            index++;    // Skip whitespace
          }
          if (json[index] == ',') {
            // Skip commas between name:value pairs
            index++;
          }
          break;    // Done
        default:
          // Unknown input. Oops.
          index++;
      }
    }
  }
  else {
    // Our JSON is empty
    return;
  }
}

void run_command(char* name, char* value) {
  // This is called for each "name":value pair found in the
  // incoming JSON. This is where you should put your handler
  // code.
  // There are a few important points to note:
  //  * This function, by default, will only be called for the
  //    top-level pairs, eg. given {"a":"b", "c":{"d":"e"}} it
  //    will be called with name="a", value="b" and name="c",
  //    value={"d":"e"}. It will not be called with name="d",
  //    value="e". If you want such recursion, add it yourself
  //    by calling read_commands on your JSON objects from
  //    somewhere within this function.
  //  * The name and value pointers will be free'd automatically
  //    after the JSON parser has finished. Thus, you should not
  //    store these pointers or any derived from them. If you
  //    want some data to persist, copy its values into some
  //    memory that you manage yourself.
  //  * Likewise, do not free these pointers yourself, as that
  //    will mangle the JSON reading.
  //  * The given pointers are not C-style strings (they are
  //    not terminated). Their length is implied by their JSON
  //    encoding. The variables "name_size" and "value_size"
  //    have been set up with the respective sizes for you if
  //    you need them.
  //  * The JSON formatting is still present in the pointers'
  //    values. For example, strings still contain their quotes.
  // Other than that, happy hacking!
  int name_size = value_length(name);
  int value_size = value_length(value);
}
