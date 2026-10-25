import Foundation
import Testing
@testable import InventoryWatch

struct PickupRequestCooldownTests {
    @Test func repeatedBlocksAlwaysPauseForExactlyOneMinute() throws {
        var cooldown = PickupRequestCooldown()
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        for _ in 0..<5 {
            cooldown.recordBlock(now: now)
            let until = now.addingTimeInterval(60)
            #expect(cooldown.nextAllowedAt == until)
            #expect(throws: AppError.self) { try cooldown.check(now: now) }
            #expect(throws: AppError.self) { try cooldown.check(now: until.addingTimeInterval(-0.001)) }
            try cooldown.check(now: until)
            now = until
        }
    }

    @Test func newSessionStartsWithoutCooldown() throws {
        var original = PickupRequestCooldown()
        original.recordBlock()
        #expect(original.nextAllowedAt != nil)
        let newSession = PickupRequestCooldown()
        #expect(newSession.nextAllowedAt == nil)
        try newSession.check()
    }

    @Test func successClearsCooldown() throws {
        var cooldown = PickupRequestCooldown()
        cooldown.recordBlock()
        cooldown.recordSuccess()
        #expect(cooldown.nextAllowedAt == nil)
        try cooldown.check()
    }

    @Test func serverDelayTakesPrecedenceButCannotShortenPause() {
        let now = Date()
        var cooldown = PickupRequestCooldown()
        cooldown.recordBlock(now: now, retryAfter: now.addingTimeInterval(10))
        #expect(cooldown.nextAllowedAt == now.addingTimeInterval(60))
        let serverDate = now.addingTimeInterval(3 * 60 * 60)
        cooldown.recordBlock(now: now, retryAfter: serverDate)
        #expect(cooldown.nextAllowedAt == serverDate)
        cooldown.deferRequests(until: now.addingTimeInterval(60))
        #expect(cooldown.nextAllowedAt == serverDate)
    }

    @Test func retryAfterAcceptsSecondsAndHTTPDate() {
        let now = Date(timeIntervalSince1970: 0)
        #expect(PickupRequestCooldown.retryAfterDate(" 120 ", now: now) == now.addingTimeInterval(120))
        #expect(PickupRequestCooldown.retryAfterDate("0", now: now) == now)
        #expect(PickupRequestCooldown.retryAfterDate("Thu, 01 Jan 1970 00:02:00 GMT", now: now) == now.addingTimeInterval(120))
        for invalid in ["", "-1", "1.5", "NaN", "Infinity", "tomorrow"] {
            #expect(PickupRequestCooldown.retryAfterDate(invalid, now: now) == nil)
        }
    }

    @Test func cooldownMessageIncludesPauseAndStaleDataWarning() {
        let until = Date().addingTimeInterval(60)
        let message = AppError.pickupCooldown(until: until).errorMessage
        #expect(message.contains(until.formatted(date: .abbreviated, time: .standard)))
        #expect(message.contains("manual refresh"))
        #expect(message.contains("out of date"))
    }
}
