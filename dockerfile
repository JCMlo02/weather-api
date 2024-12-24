FROM public.ecr.aws/lambda/nodejs:22 as builder

WORKDIR /usr/app

# Copy the package.json and package-lock.json first to install dependencies
COPY package*.json ./
RUN npm install

# Copy the rest of the application code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM public.ecr.aws/lambda/nodejs:22

WORKDIR ${LAMBDA_TASK_ROOT}

# Copy the built application from the builder stage
COPY --from=builder /usr/app/dist/ ./

# Ensure the handler function is correctly defined in the Lambda environment
CMD ["index.handler"]