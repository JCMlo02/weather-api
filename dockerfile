# Step 1: Use the official AWS Lambda Node.js base image
FROM public.ecr.aws/lambda/nodejs:16

# Step 2: Set the working directory in the container
WORKDIR $LAMBDA_TASK_ROOT
RUN npm install
RUN npm run build
# Step 3: Copy the Lambda function code and package.json into the container
COPY . .

# Step 5: Set the CMD to your Lambda function handler
CMD [ "dist/handler.handler" ]