export default {
	async fetch(request, env, ctx) {
	  try {
		// Check for authentication
		const authHeader = request.headers.get('Authorization');
		if (!authHeader || !authHeader.startsWith('Bearer ')) {
		  return new Response('Unauthorized: Missing or invalid token', { status: 401 });
		}
		
		// Define variables for prompt and image parts
		let prompt;
		let imageParts = [];
  
		if (request.method === "GET") {
		  const { searchParams } = new URL(request.url);
		  prompt = searchParams.get("prompt");
		} else if (request.method === "POST") {
		  const contentType = request.headers.get("content-type") || "";
		  // Check if the request is multipart/form-data
		  if (contentType.includes("multipart/form-data")) {
			const formData = await request.formData();
			prompt = formData.get("prompt");
			if (!prompt) {
			  return new Response("Missing prompt", { status: 400 });
			}
			
			// Extract all image files; assuming the field name is "images"
			const images = formData.getAll("images");
			for (const image of images) {
			  // image is a File object. Read as an ArrayBuffer.
			  const buffer = await image.arrayBuffer();
			  // Convert the ArrayBuffer to a Base64 string.
			  const uint8Array = new Uint8Array(buffer);
			  let binary = '';
			  for (let i = 0; i < uint8Array.byteLength; i++) {
				binary += String.fromCharCode(uint8Array[i]);
			  }
			  const base64Image = btoa(binary);
			  // Create an image part per Gemini Vision API using inlineData.
			  imageParts.push({
				inlineData: {
				  data: base64Image,
				  mimeType: image.type // e.g. "image/jpeg" or "image/png"
				}
			  });
			}
		  } else {
			// Fallback: if using a JSON payload (possibly containing images as Base64)
			const data = await request.json();
			prompt = data.prompt;
			if (!prompt) {
			  return new Response("Missing prompt", { status: 400 });
			}
			if (data.images && Array.isArray(data.images)) {
			  imageParts = data.images.map(img => ({
				inlineData: {
				  data: img.data,
				  mimeType: img.mime_type
				}
			  }));
			}
		  }
		}
		
		// If no prompt was provided, return an error.
		if (!prompt) {
		  return new Response("Missing prompt", { status: 400 });
		}
		
		// Construct the Gemini API URL (using your Gemini model endpoint)
		const apikey = `AIzaSyCJtymXxwho9G9womXQD12HDZJNBbZjVqU`;
		const apiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${apikey}`;
		
		// Build the payload.
		// Note: If sending a single image, per documentation, you may want to place the text prompt after the image part.
		// Here we assume that if there are any image parts, we place them first.
		const parts = imageParts.length > 0 ? [...imageParts, { text: prompt }] : [{ text: prompt }];
		
		const payload = {
		  contents: {
			role: "user",
			parts: parts
		  },
		  generation_config: {
			temperature: 0.25,
			top_p: 0.95,
			max_output_tokens: 1024
		  }
		};
		
		// Call the Gemini inference API.
		const apiResponse = await fetch(apiUrl, {
		  method: "POST",
		  headers: { "Content-Type": "application/json" },
		  body: JSON.stringify(payload)
		});
		
		if (!apiResponse.ok) {
		  const errorText = await apiResponse.text();
		  return new Response(`Error from Gemini API: ${errorText}`, { status: apiResponse.status });
		}
		
		// Return the response from Gemini to the user.
		const result = await apiResponse.text();
		return new Response(result, {
		  headers: { "Content-Type": "application/json" }
		});
		
	  } catch (err) {
		return new Response("Internal Error: " + err.message, { status: 500 });
	  }
	}
  };
  