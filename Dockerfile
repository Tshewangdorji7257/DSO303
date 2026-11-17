# The USMS enrolment service: a static portal served by nginx.
# The build context must already contain dist/, produced by buildspec.yml's build phase.
FROM nginx:1.27-alpine

# Copy the BUILT output, not the source tree.
COPY dist/ /usr/share/nginx/html/

# Lab 04's health check and Lab 05's target group both need port 80.
EXPOSE 80
