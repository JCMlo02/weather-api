FROM public.ecr.aws/lambda/nodejs:22 as builder

WORKDIR /usr/app

# Copy the package.json and package-lock.json first to install dependencies
COPY . .
RUN npm install
RUN npm run build

# Production stage
FROM public.ecr.aws/lambda/nodejs:22

WORKDIR /

# Copy the built application from the builder stage
COPY package.json ${LAMBDA_TASK_ROOT}
COPY --from=builder /usr/app/dist/ ${LAMBDA_TASK_ROOT}/
COPY --from=builder /usr/app/node_modules/ ${LAMBDA_TASK_ROOT}/node_modules/
RUN npm prune --legacy-peer-deps
# Ensure the handler function is correctly defined in the Lambda environment
CMD ["index.handler"]