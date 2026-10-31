import 'package:flutter_test/flutter_test.dart';
import 'package:nearbnb_app/core/format.dart';

void main() {
  test('money: cents to dollars, cents shown only when there are some', () {
    expect(money(25000), r'$250');
    expect(money(25050), r'$250.50');
    expect(money(0), r'$0');
    expect(money(null), '');
  });

  test('time labels read like the website', () {
    expect(timeLabel('14:00'), '2:00 pm');
    expect(timeLabel('00:30'), '12:30 am');
    expect(timeLabel('12:00'), '12:00 pm');
  });

  test('check-in times follow the interval inside the unit window', () {
    expect(timeOptions(60, '08:00', '11:00'), ['08:00', '09:00', '10:00', '11:00']);
    expect(timeOptions(30, '08:15', '09:30'), ['08:30', '09:00', '09:30']);
    expect(timeOptions(0, '08:00', '09:00'), ['08:00', '09:00']); // a bad setting never loops forever
  });

  test('time left and plurals', () {
    expect(timeLeft(30), 'under a minute');
    expect(timeLeft(8 * 60), '8 min');
    expect(timeLeft(2 * 3600 + 15 * 60), '2 h 15 min');
    expect(timeLeft(3 * 3600), '3 h');
    expect(plural(1, 'night'), '1 night');
    expect(plural(3, 'night'), '3 nights');
    expect(plural(2, 'place to stay', 'places to stay'), '2 places to stay');
  });
}
