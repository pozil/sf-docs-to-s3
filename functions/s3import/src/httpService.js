import https from 'https';

export class HttpService {
    static async request(options, body) {
        return new Promise((resolve, reject) => {
            const req = https.request(options, (res) => {
                if (res.statusCode !== 200) {
                    reject(
                        new Error(
                            `Error in GET request: HTTP ${res.statusCode} ${
                                res.statusMessage
                            } - ${JSON.stringify(options)}`
                        )
                    );
                }
                let data = [];
                res.on('data', (chunk) => {
                    data.push(chunk);
                }).on('end', () => {
                    resolve(Buffer.concat(data));
                });
            });

            req.on('error', (err) => {
                reject(
                    new Error(
                        `Error in GET request: HTTP ${res.statusCode} ${
                            res.statusMessage
                        } - ${JSON.stringify(options)}`,
                        { cause: err }
                    )
                );
            });

            if (body) {
                req.write(body);
            }

            req.end();
        });
    }
}
