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
    Serial.println("Unknown input");
  }
  else {
    int length = json_length(input);
    Serial.print("Found ");
    Serial.print(length);
    Serial.println(" chars of JSON");
    for (int i=0; i < length; i++) {
      Serial.print(input[i]);
    }
    Serial.println("");
  }
}

int read_char()
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
    Serial.println("Unknown input. Please send me JSON");
    // Try again...
    this_value = read_char();
  }
  int nested_count = 1;    // Keep track of how deeply nested our braces are
  int input_size = 2;      // The size of our char pointer (must be >= 2, for '{' and '}')
  int read_so_far = 1;     // How much data we've read (used to ensure our pointer is big enough)
  int i;                   // Loop indexing
  char* result = (char*) malloc(sizeof(char)*input_size);    // Allocate our array
  char* new_result;    // Used for increasing our array size as neccessary
  result[0] = this_value;    // Set the first value to the '{' that we found
  while (nested_count > 0)    // Loop until we've closed that first brace
  {
    Serial.print("Nested to ");
    Serial.println(nested_count);
    // Wait for input then read it
    this_value = read_char();
    
    // See if we've got enough room to store it
    read_so_far++;
    if (read_so_far > input_size)
    {
      // Try to increase the size of our instruction pointer
      char* new_result = (char*) realloc(result, (input_size+1));
      if (new_result)
      {
        // We succeeded in allocating enough memory. Let's use it.
        result = new_result;
        input_size++;
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
    if (this_value == '{') {
      nested_count++;
    }
    else {
      if (this_value == '}') {
        nested_count--;
      }
      else {
        // Some other character
      }
    }
  }
  return result;
}

int json_length(char* json) {
  // Give this a pointer to some JSON data and it will
  // return the length of that JSON.
  
  if (json == 0) {
    // Null pointer, so no JSON
    Serial.println("Doesn't look like JSON");
    return 0;
  }
  
  int index = 0;
  if (json[index] != '{') {
    // Not JSON
    Serial.println("This isn't JSON, it's...");
    Serial.println(json[index]);
    return 0;
  }
  
  // We've got an open brace, so start at the next char
  int nesting = 1;
  int length = 1;
  index++;
  
  // Now we loop until we've closed the initial brace
  while (nesting > 0) {
    
    // Recurse one level FIXME: We need to allow { in strings
    if (json[index] == '{') {
      nesting++;
    }
    else {
      
      // Go up one level FIXME: We need to allow } in strings
      if (json[index] == '}') {
        nesting--;
      }
      else {
        // Some other character
      }
    }
    length++;
    index++;
  }
  return length;
}
