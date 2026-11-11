import 'package:flutter/foundation.dart';

/// A spiritual interest chosen in onboarding. Each interest maps onto one or
/// more discovery topics, which drives Home and Discover recommendations.
@immutable
class SpiritualInterest {
  const SpiritualInterest(this.id, this.label, this.description, this.topicIds);

  final String id;
  final String label;
  final String description;
  final List<String> topicIds;
}

const List<SpiritualInterest> spiritualInterests = [
  SpiritualInterest('faith', 'Faith', 'Trusting God in every season', ['faith', 'trusting-god']),
  SpiritualInterest('prayer', 'Prayer', 'Growing a daily prayer life', ['prayer', 'fasting']),
  SpiritualInterest('understanding', 'Understanding Scripture', 'Reading the Bible with insight', [
    'knowing-god',
    'wisdom',
  ]),
  SpiritualInterest('growth', 'Spiritual growth', 'Maturing in faith and character', ['spiritual-growth']),
  SpiritualInterest('family', 'Family', 'Marriage, parenting and home', ['family', 'love']),
  SpiritualInterest('purpose', 'Purpose', 'Discovering God’s calling', ['purpose']),
  SpiritualInterest('wisdom', 'Wisdom', 'Making wise, godly decisions', ['wisdom']),
  SpiritualInterest('living', 'Christian living', 'Faith in everyday life', ['christian-living', 'forgiveness']),
  SpiritualInterest('development', 'Personal development', 'Leadership, stewardship and growth', [
    'leadership',
    'money',
    'wealth',
  ]),
];

Set<String> topicIdsForInterests(Iterable<String> interestIds) => {
  for (final i in spiritualInterests.where((s) => interestIds.contains(s.id))) ...i.topicIds,
};
