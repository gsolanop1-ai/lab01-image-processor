"use strict";

const { S3Client, GetObjectCommand, PutObjectCommand } = require("@aws-sdk/client-s3");
const sharp = require("sharp");

const s3 = new S3Client({ region: process.env.AWS_REGION });
const OUTPUT_SIZE = 40;

// Máscara SVG circular para producir esquinas redondeadas transparentes
const CIRCLE_MASK = Buffer.from(
  `<svg><circle cx="${OUTPUT_SIZE / 2}" cy="${OUTPUT_SIZE / 2}" r="${OUTPUT_SIZE / 2}"/></svg>`
);

exports.handler = async (event) => {
  const results = await Promise.allSettled(
    event.Records.map((record) => procesarRegistro(record))
  );

  // ReportBatchItemFailures — solo reintenta los mensajes fallidos
  const batchItemFailures = results
    .map((result, index) => ({ result, record: event.Records[index] }))
    .filter(({ result }) => result.status === "rejected")
    .map(({ result, record }) => {
      console.error(`Falló messageId=${record.messageId}:`, result.reason);
      return { itemIdentifier: record.messageId };
    });

  return { batchItemFailures };
};

async function procesarRegistro(record) {
  const notification = JSON.parse(record.body);
  const s3Event = notification.Records?.[0]?.s3;

  if (!s3Event) {
    // S3 envía un evento de prueba al configurar la notificación — se descarta silenciosamente
    console.log("No hay evento S3 en el cuerpo del registro, omitiendo:", record.messageId);
    return;
  }

  const bucketName = s3Event.bucket.name;
  const objectKey = decodeURIComponent(s3Event.object.key.replace(/\+/g, " "));

  // Descargar el original desde uploads/
  const getResp = await s3.send(
    new GetObjectCommand({ Bucket: bucketName, Key: objectKey })
  );
  const inputBuffer = Buffer.concat(await streamToChunks(getResp.Body));

  // Redimensionar a 40x40 cover, aplicar máscara SVG circular y exportar como png
  const circularPng = await sharp(inputBuffer)
    .resize(OUTPUT_SIZE, OUTPUT_SIZE, { fit: "cover", position: "centre" })
    .png()
    .composite([{ input: CIRCLE_MASK, blend: "dest-in" }])
    .toBuffer();

  // Guardar en processed/ con sufijo _circular
  const baseName = objectKey.split("/").pop().replace(/\.[^.]+$/, "");
  const outputKey = `${process.env.PROCESSED_PREFIX}${baseName}_circular.png`;

  await s3.send(
    new PutObjectCommand({
      Bucket: process.env.S3_BUCKET,
      Key: outputKey,
      Body: circularPng,
      ContentType: "image/png",
    })
  );

  console.log(`Procesado: ${objectKey} → ${outputKey} (${circularPng.length} bytes)`);
}

async function streamToChunks(stream) {
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  return chunks;
}