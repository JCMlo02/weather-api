# Step 1: Use the official AWS Lambda Node.js base image
FROM public.ecr.aws/lambda/nodejs:16

# Step 2: Set the working directory in the container
WORKDIR /var/task

# Step 3: Copy the Lambda function code and package.json into the container
COPY . .

# Step 4: Install dependencies
RUN npm install
RUN npm run build

# Step 5: Set the CMD to your Lambda function handler
CMD [ "src.handler.handler" ]