export default {
	async fetch(request, env, ctx) {
	  try {
		// Check for authentication
		const authHeader = request.headers.get('Authorization');
		if (!authHeader || !authHeader.startsWith('Bearer ')) {
		  return new Response('Unauthorized: Missing or invalid token', { status: 401 });
		}
		
		const token = authHeader.split(' ')[1];
		
		// Validate the token with Auth0
		// In a production environment, you should verify the JWT token
		// This is a simplified example
		
		// Extract the prompt from the URL query (GET) or request JSON body (POST)
		let prompt = "Tell me a really funny joke";
		if (request.method === "GET") {
		  const { searchParams } = new URL(request.url);
		  prompt = searchParams.get("prompt");
		} else if (request.method === "POST") {
		  const data = await request.json();
		  prompt = data.prompt;
		}
		if (!prompt) {
		  return new Response("Missing prompt", { status: 400 });
		}
  
		// Construct the Gemini inference API endpoint
		// Replace "gemini-1.5-flash-latest" with the correct model identifier if needed.
		const apikey = `AIzaSyCJtymXxwho9G9womXQD12HDZJNBbZjVqU`
		const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${apikey}`;
  
		// Build the payload with the requested prompt and generation settings
		const payload = {
		  contents: {
			role: "user",
			parts: [{ text: prompt }]
		  },
		  generation_config: {
			temperature: 0.25,
			top_p: 0.95,
			max_output_tokens: 1024
		  }
		};
  
		// Call the Gemini inference API
		const apiResponse = await fetch(apiUrl, {
		  method: "POST",
		  headers: { "Content-Type": "application/json" },
		  body: JSON.stringify(payload)
		});
  
		if (!apiResponse.ok) {
		  const errorText = await apiResponse.text();
		  return new Response(`Error from Gemini API: ${errorText}`, { status: apiResponse.status });
		}
  
		// Return the response from Gemini to the user
		const result = await apiResponse.text();
		return new Response(result, {
		  headers: { "Content-Type": "application/json" }
		});
	  } catch (err) {
		return new Response("Internal Error: " + err.message, { status: 500 });
	  }
	}
  };
  