"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handler = void 0;
const client_s3_1 = require("@aws-sdk/client-s3");
const handler = async (event) => {
    let location;
    if (event.body) {
        let parsedObj = JSON.parse(event.body);
        location = parsedObj.location || "Charlotte";
    }
    const apiKey = process.env.API_KEY;
    const url = `https://api.tomorrow.io/v4/weather/forecast?location=${location}&timesteps=1d&apikey=${apiKey}`;
    const s3Key = `weather-${location}.json`;
    const bucket = "weather-project-data-bucket";
    const s3 = new client_s3_1.S3Client({
        region: "us-east-1",
    });
    const twelveHoursInMs = 12 * 60 * 60 * 1000;
    try {
        const getObject = new client_s3_1.GetObjectCommand({ Bucket: bucket, Key: s3Key });
        const s3Object = await s3.send(getObject);
        const lastModified = s3Object.LastModified?.getTime() || 0;
        const currentTime = Date.now();
        const cacheAge = currentTime - lastModified;
        if (cacheAge < twelveHoursInMs) {
            const readableObject = Buffer.isBuffer(s3Object.Body)
                ? JSON.parse(s3Object.Body.toString("utf-8"))
                : new Error("Unable to read Object");
            if (typeof readableObject === "object") {
                return readableObject;
            }
            throw readableObject || new Error("Unable to read Object");
        }
        throw new Error("Cache is too old");
    }
    catch (error) {
        const request = await fetch(url, {
            method: "GET",
            headers: {
                "Content-Type": "application/json",
            },
        });
        const response = request.json();
        const sendObject = new client_s3_1.PutObjectCommand({
            Bucket: bucket,
            Key: s3Key,
            Body: JSON.stringify(response),
        });
        await s3.send(sendObject);
        return response;
    }
};
exports.handler = handler;
