# Use the specified ollama Docker image as the base
FROM ollama/ollama:0.3.2

# Install necessary packages
RUN apt-get update && \
    apt-get install -y curl jq xclip && \
    apt-get clean

# Copy the script to the container
COPY start_ollama.sh /usr/local/bin/start_ollama.sh
RUN chmod +x /usr/local/bin/start_ollama.sh

RUN /usr/local/bin/start_ollama.sh && ollama pull llama3.2

COPY script.sh /usr/local/bin/run_script.sh
RUN chmod +x /usr/local/bin/run_script.sh
WORKDIR /root/.config
# Set the default command to execute the script
ENTRYPOINT ["/usr/local/bin/run_script.sh"]

# Example usage to pass ISSUE_ID when running the container:
# docker run --rm -e ISSUE_ID=your_issue_id <image_name>
