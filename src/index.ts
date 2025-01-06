import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
} from "@aws-sdk/client-s3";
import { APIGatewayEvent } from "aws-lambda";

const s3 = new S3Client({ region: "us-east-1" });
const bucket = "weather-project-data-bucket"; // Move this outside the handler to avoid re-declaring
const twelveHoursInMs = 12 * 60 * 60 * 1000; // Cache expiration time

// Fetch weather data from the external API
const fetchWeatherData = async (location: string, apiKey: string) => {
  const url = `https://api.tomorrow.io/v4/weather/forecast?location=${location}&timesteps=1d&apikey=${apiKey}`;
  console.log(`Fetching weather data for location: ${location}`);

  try {
    const response = await fetch(url, {
      method: "GET",
      headers: { "Content-Type": "application/json" },
    });
    if (!response.ok) {
      throw new Error(`Failed to fetch weather data: ${response.statusText}`);
    }
    const data = await response.json();
    console.log(`Fetched weather data for location: ${location}`, data);
    return data;
  } catch (error) {
    console.error(`Error fetching weather data for ${location}:`, error);
    throw error;
  }
};

// Get data from S3 and check if it's fresh
const getWeatherFromS3 = async (location: string) => {
  const s3Key = `weather-${location.toLowerCase()}.json`;
  const getObject = new GetObjectCommand({ Bucket: bucket, Key: s3Key });

  try {
    console.log(
      `Checking S3 for cached weather data for location: ${location}`
    );
    const s3Object = await s3.send(getObject);

    const lastModified = s3Object.LastModified?.getTime() || 0;
    const cacheAge = Date.now() - lastModified;

    console.log(
      `S3 data last modified at: ${new Date(lastModified).toISOString()}`
    );
    console.log(`Cache age is: ${cacheAge}ms`);

    if (cacheAge < twelveHoursInMs) {
      const readableObject = Buffer.isBuffer(s3Object.Body)
        ? JSON.parse(s3Object.Body.toString("utf-8"))
        : null;

      if (readableObject) {
        console.log(`Returning cached data for location: ${location}`);
        return readableObject;
      } else {
        throw new Error("Unable to parse cached S3 object");
      }
    }
    throw new Error("Cache is too old");
  } catch (error) {
    console.error(
      `Error getting weather data from S3 for location: ${location}`,
      error
    );
    throw error;
  }
};

// Save data to S3
const saveWeatherToS3 = async (location: string, data: any) => {
  const s3Key = `weather-${location.toLowerCase()}.json`;
  const putObject = new PutObjectCommand({
    Bucket: bucket,
    Key: s3Key,
    Body: JSON.stringify(data),
  });

  try {
    console.log(`Saving fresh weather data to S3 for location: ${location}`);
    await s3.send(putObject);
    console.log(`Data saved to S3 for location: ${location}`);
  } catch (error) {
    console.error(
      `Error saving weather data to S3 for location: ${location}`,
      error
    );
    throw error;
  }
};

export const handler = async (event: APIGatewayEvent) => {
  let location = "Charlotte"; // Default location
  if (event.body) {
    const parsedObj = JSON.parse(event.body);
    location = parsedObj.location || "Charlotte"; // Fallback to default if no location provided
    console.log("Parsed object:", parsedObj);
  }

  const apiKey = process.env.API_KEY;
  if (!apiKey) {
    console.error("API_KEY environment variable is not set");
    return {
      statusCode: 500,
      headers: {
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "OPTIONS,POST",
      },
      body: JSON.stringify({
        error: "API_KEY environment variable is missing",
      }),
    };
  }

  try {
    // Try to get weather data from S3 first
    const weatherData = await getWeatherFromS3(location);
    return {
      statusCode: 200,
      headers: {
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "OPTIONS,POST",
      },
      body: JSON.stringify(weatherData),
    };
  } catch (s3Error) {
    // If S3 data is not available or expired, fetch fresh data from the API
    console.log("Fetching fresh data from external API...");
    try {
      const freshWeatherData = await fetchWeatherData(location, apiKey);
      // Save the fresh data to S3 for future requests
      await saveWeatherToS3(location, freshWeatherData);

      return {
        statusCode: 200,
        headers: {
          "Access-Control-Allow-Headers": "Content-Type",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "OPTIONS,POST",
        },
        body: JSON.stringify(freshWeatherData),
      };
    } catch (apiError) {
      // If both S3 and API calls fail
      console.error("Error handling the request", apiError);
      return {
        statusCode: 500,
        headers: {
          "Access-Control-Allow-Headers": "Content-Type",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "OPTIONS,POST",
        },
        body: JSON.stringify({ error: "Unable to fetch weather data" }),
      };
    }
  }
};
