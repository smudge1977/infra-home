// Zigbee2MQTT 1.41 external extension: only genuine incoming localTemp values.
const TRVS = new Set([
    '0x983268fffe983af9', '0x449fdafffe751ed3',
    '0x983268fffe98d307', '0x983268fffe98ee81',
]);

class HeatmeshTemperatureReceipts {
    constructor(zigbee, mqtt, state, publishEntityState, eventBus) {
        this.mqtt = mqtt;
        this.eventBus = eventBus;
    }

    async start() {
        this.eventBus.onDeviceMessage(this, async (message) => {
            const ieee = message.device?.ieeeAddr;
            if (!TRVS.has(ieee) || message.cluster !== 'hvacThermostat' ||
                !['attributeReport', 'readResponse'].includes(message.type) ||
                !Object.prototype.hasOwnProperty.call(message.data || {}, 'localTemp')) return;
            const raw = message.data.localTemp;
            if (!Number.isInteger(raw) || raw < -27315 || raw > 32767) return;
            await this.mqtt.publish(`heatmesh/temperature/${ieee}`, JSON.stringify({
                temperature: raw / 100,
                // Observation of incoming Zigbee message, not internal sampling time.
                observed_at: new Date().toISOString(),
            }), {retain: true, qos: 1}, 'zigbee2mqtt');
        });
    }

    async stop() { this.eventBus.removeListeners(this); }
}

module.exports = HeatmeshTemperatureReceipts;