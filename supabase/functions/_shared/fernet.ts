/**
 * Fernet decryption implementation for Deno using Web Crypto API.
 * Fernet spec: https://github.com/fernet/spec/blob/master/Spec.md
 */

export async function decryptFernet(token: Uint8Array, keyBase64: string): Promise<string> {
  // 1. Decode Key
  const keyBuffer = Uint8Array.from(atob(keyBase64.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
  if (keyBuffer.length !== 32) throw new Error("Invalid Fernet key length");

  const signingKey = keyBuffer.slice(0, 16);
  const encryptionKey = keyBuffer.slice(16);

  // 2. Parse Token
  if (token[0] !== 0x80) throw new Error("Invalid Fernet version");
  
  const iv = token.slice(9, 25);
  const ciphertext = token.slice(25, token.length - 32);
  const hmacReceived = token.slice(token.length - 32);

  // 3. Verify HMAC (Mandatory for security)
  const hmacKey = await crypto.subtle.importKey(
    "raw", signingKey, { name: "HMAC", hash: "SHA-256" }, false, ["verify"]
  );
  const dataToSign = token.slice(0, token.length - 32);
  const isValid = await crypto.subtle.verify("HMAC", hmacKey, hmacReceived, dataToSign);
  if (!isValid) throw new Error("Invalid Fernet HMAC signature");

  // 4. Decrypt AES-128-CBC
  const aesKey = await crypto.subtle.importKey(
    "raw", encryptionKey, { name: "AES-CBC" }, false, ["decrypt"]
  );
  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-CBC", iv }, aesKey, ciphertext
  );

  return new TextDecoder().decode(decrypted);
}
