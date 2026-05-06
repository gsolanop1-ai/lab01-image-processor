"use strict";

const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const busboy = require("busboy");
const { v4: uuidv4 } = require("uuid");

const s3 = new S3Client({ region: process.env.AWS_REGION });

const ALLOWED_MIME_TYPES = new Set(["image/jpeg", "image/png", "image/gif", "image/webp"]);
const MAX_BYTES = 10 * 1024 * 1024; // 10 MB

exports.handler = async (event) => {
  const contentType =
    event.headers?.["content-type"] ||
    event.headers?.["Content-Type"] ||
    "";

  try {
    let fileBuffer, mimeType, originalName;

    if (contentType.includes("multipart/form-data")) {
      const parsed = await parseMultipart(event);
      fileBuffer = parsed.buffer;
      mimeType = parsed.mimeType;
      originalName = parsed.name;
    } else if (contentType.includes("application/json")) {
      const body = JSON.parse(event.body || "{}");
      if (!body.image || !body.name) {
        return reply(400, { error: "JSON body requires 'image' (base64 data-URI) and 'name'" });
      }
      const match = body.image.match(/^data:([^;]+);base64,(.+)$/);
      if (!match) {
        return reply(400, { error: "Invalid base64 data-URI in 'image' field" });
      }
      mimeType = match[1];
      if (!ALLOWED_MIME_TYPES.has(mimeType)) {
        return reply(400, { error: `Unsupported type '${mimeType}'. Allowed: jpg, png, gif, webp` });
      }
      fileBuffer = Buffer.from(match[2], "base64");
      originalName = body.name;
    } else {
      return reply(415, { error: "Content-Type must be multipart/form-data or application/json" });
    }

    if (!ALLOWED_MIME_TYPES.has(mimeType)) {
      return reply(400, { error: `Unsupported type '${mimeType}'. Allowed: jpg, png, gif, webp` });
    }
    if (fileBuffer.length > MAX_BYTES) {
      return reply(413, { error: "File exceeds 10 MB maximum" });
    }

    const ext = mimeType.split("/")[1].replace("jpeg", "jpg");
    const fileId = uuidv4();
    const key = `${process.env.UPLOAD_PREFIX}${fileId}.${ext}`;

    await s3.send(
      new PutObjectCommand({
        Bucket: process.env.S3_BUCKET,
        Key: key,
        Body: fileBuffer,
        ContentType: mimeType,
        Metadata: { originalName: originalName || "unknown" },
      })
    );

    console.log(`Subido: ${key} (${fileBuffer.length} bytes)`);
    return reply(200, { message: "Upload successful", fileId, key });
  } catch (err) {
    console.error("Error en handler de carga:", err);
    return reply(500, { error: "Internal server error" });
  }
};

function parseMultipart(event) {
  return new Promise((resolve, reject) => {
    const bb = busboy({
      headers: {
        "content-type":
          event.headers["content-type"] || event.headers["Content-Type"],
      },
      limits: { fileSize: MAX_BYTES },
    });

    let result = null;

    bb.on("file", (_field, stream, info) => {
      if (!ALLOWED_MIME_TYPES.has(info.mimeType)) {
        stream.resume();
        return reject(new Error(`Tipo MIME no soportado: ${info.mimeType}`));
      }
      const chunks = [];
      stream.on("data", (d) => chunks.push(d));
      stream.on("limit", () => reject(new Error("El archivo supera el límite de 10 MB")));
      stream.on("end", () => {
        result = {
          buffer: Buffer.concat(chunks),
          mimeType: info.mimeType,
          name: info.filename,
        };
      });
    });

    bb.on("finish", () => {
      if (!result) return reject(new Error("No se encontró archivo en la solicitud multipart"));
      resolve(result);
    });

    bb.on("error", reject);

    const raw = event.isBase64Encoded
      ? Buffer.from(event.body, "base64")
      : Buffer.from(event.body || "");

    bb.write(raw);
    bb.end();
  });
}

function reply(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}