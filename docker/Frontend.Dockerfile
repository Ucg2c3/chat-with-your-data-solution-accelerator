FROM node:20-alpine AS frontend
RUN mkdir -p /home/node/app/node_modules && chown -R node:node /home/node/app
WORKDIR /home/node/app
COPY ./code/frontend/package*.json ./
USER node
# RUN npm install --force
RUN npm ci
COPY --chown=node:node ./code/frontend ./frontend
WORKDIR /home/node/app/frontend
RUN npm install --save-dev @types/node @types/jest
RUN npm run build

FROM python:3.11.7-bookworm
RUN apt-get update && apt-get install python3-tk tk-dev -y

COPY pyproject.toml /usr/src/app/pyproject.toml
COPY poetry.lock /usr/src/app/poetry.lock
WORKDIR /usr/src/app
RUN pip install --upgrade pip && pip install poetry uwsgi && poetry self add poetry-plugin-export && poetry export -o requirements.txt && pip install -r requirements.txt

COPY ./code/*.py /usr/src/app/
COPY ./code/backend /usr/src/app/backend
COPY --from=frontend /home/node/app/dist/static /usr/src/app/static/
# https://github.com/docker/buildx/issues/2751
ENV PYTHONPATH="${PYTHONPATH}:/usr/src/app"
EXPOSE 80
CMD ["uwsgi", "--http", ":80", "--wsgi-file", "app.py", "--callable", "app", "-b", "32768", "--http-timeout", "230"]
