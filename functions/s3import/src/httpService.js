import https from 'https';

export class HttpService {
    static async get(options) {
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
            req.end();
        });
    }
}
