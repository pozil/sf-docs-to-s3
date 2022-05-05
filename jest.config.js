/* eslint-env es2021 */
const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    testRegex: '/__tests__/.*.test.js$',
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver']
};
