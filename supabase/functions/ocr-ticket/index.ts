
// Define CORS headers locally to avoid import issues
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  // 1. Handle CORS Preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log("OCR Function Started");

    // 2. Check API Key
    const apiKey = Deno.env.get('OPENROUTER_API_KEY');
    if (!apiKey) {
      throw new Error("OPENROUTER_API_KEY is not configured in Supabase Secrets");
    }

    // 3. Parse Body
    let body;
    try {
      body = await req.json();
    } catch (e) {
      throw new Error("Invalid JSON body");
    }

    const { imageBase64 } = body;
    if (!imageBase64) {
      throw new Error("Missing 'imageBase64' field in request body");
    }

    // 4. Validate Image Data
    // Ensure it's a valid Data URI. If not, maybe add prefix, but frontend uses readAsDataURL so it SHOULD be there.
    // We will trust the input to be a full Data URI or handle the prefix logic carefully.
    let finalImageUrl = imageBase64;
    if (!imageBase64.startsWith('data:')) {
      // Fallback if frontend sent just the raw base64 (unlikely based on TallyInput.tsx)
      finalImageUrl = `data:image/jpeg;base64,${imageBase64}`;
    }

    console.log("Calling OpenRouter...");

    // 5. Call OpenRouter API
    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
        "HTTP-Referer": "https://coal-logix.com",
        "X-Title": "CoalLogix",
      },
      body: JSON.stringify({
        "model": "google/gemini-2.5-flash",
        "messages": [
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": "Extract data from this dot-matrix weighbridge ticket. Return JSON with keys: truck_plate (string), ticket_number (string), gross_weight (number, remove dots), tare_weight (number, remove dots), net_weight (number, remove dots). In Indonesia 40.000 means 40000."
              },
              {
                "type": "image_url",
                "image_url": {
                  "url": finalImageUrl
                }
              }
            ]
          }
        ]
      })
    });

    const result = await response.json();

    // Check for OpenRouter API Error
    if (result.error) {
      console.error("OpenRouter API Error:", result.error);
      throw new Error(`OpenRouter Error: ${result.error.message || JSON.stringify(result.error)}`);
    }

    if (!result.choices || result.choices.length === 0) {
      throw new Error("No choices returned from AI");
    }

    const rawContent = result.choices[0].message.content;
    console.log("AI Response:", rawContent);

    // 6. Parse JSON from AI Response
    // Robust cleaning of markdown blocks
    const cleanJson = rawContent.replace(/```json/g, '').replace(/```/g, '').trim();
    let parsedData;
    try {
      parsedData = JSON.parse(cleanJson);
    } catch (e) {
      console.error("JSON Parse Error:", e);
      throw new Error(`Failed to parse AI response as JSON: ${rawContent}`);
    }

    // 7. Success Response
    return new Response(JSON.stringify(parsedData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error: any) {
    console.error("OCR FUNCTION ERROR:", error);
    // 8. Error Tunneling
    // Return 200 OK with success: false so frontend can read the message
    return new Response(JSON.stringify({
      success: false,
      error: error.message || String(error)
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  }
});