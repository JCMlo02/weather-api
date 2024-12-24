# Step 1: Use the official AWS Lambda Node.js base image
FROM public.ecr.aws/lambda/nodejs:16

# Step 2: Set the working directory in the container
WORKDIR /var/task

# Step 3: Copy package.json and package-lock.json first to leverage Docker cache
COPY package.json ./

# Step 4: Install dependencies
RUN npm install

# Step 5: Copy the rest of the project files (including source code, excluding unnecessary files)
COPY . .

# Step 6: Run the build step (e.g., TypeScript compilation)
RUN npm run build

# Step 7: Set the CMD to your Lambda function handler
CMD [ "dist/handler.handler" ]