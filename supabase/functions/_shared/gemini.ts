import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai";

/**
 * Generates content with a primary model and falls back to a secondary model if it fails.
 */
export async function generateContentWithFallback(
  apiKey: string,
  prompt: string,
  config: { temperature?: number; responseMimeType?: string } = {}
) {
  const genAI = new GoogleGenerativeAI(apiKey);
  // Using 3.1-flash-lite-preview as primary and 2.5-flash-lite as fallback as requested
  const models = ["gemini-3.1-flash-lite-preview", "gemini-2.5-flash-lite"];
  
  let lastError;
  for (const modelName of models) {
    try {
      console.log(`[GEMINI] Attempting generation with model: ${modelName}`);
      const model = genAI.getGenerativeModel({ 
        model: modelName,
        generationConfig: config
      });
      const result = await model.generateContent(prompt);
      
      // Basic check to ensure we have a valid response
      if (result && result.response) {
        return result;
      }
    } catch (error) {
      console.error(`[GEMINI] Model ${modelName} failed: ${error.message}`);
      lastError = error;
    }
  }
  
  throw lastError || new Error("All Gemini models failed to generate content.");
}
