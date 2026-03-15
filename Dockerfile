FROM node:24 

WORKDIR /app

COPY . .

RUN npm install

EXPOSE 3000

CMD ["node","app.js"]